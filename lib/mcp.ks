boot:require("std").

////
// Control access to spacecraft controls in an orderly fashion across mutliple triggers and execution threads.
// Any trigger or thread that wishes to access the systems defined in mcp:systems, except any abort or emergency sequences, must follow this pattern.
// 
// mcp:init         - Executed only once per per script run, at the very beginning of operations before any code takes control of any system.
// mcp:register     - Each "caller" (either the main script or each trigger) should call this method and store the returned ticketId.
// mcp:acquire      -  Acquire an exclusive lock on whichever subsystems the script or trigger wants to manipulate.  From this point forward, only the
//                     holder of the ticket that acquired the lock should touch the subsystems.  All others will block in thier respective mcp:acquire calls.
//                     Each caller should do their work with the subsystems quickly, and then release the lock as soon as possible.  In some cases, such as a hoverslam,
//                     the thread that is performing the descent might want to hold exclusive access for an extending period of time to ensure no other triggers or callers
//                     interferes.  This should be the exception, not the rule.
// mcp:release      -  Release an exclusive lock held on subsystems, allowing other threads or triggers access to it.
// mcp:abort        -  Should only be called by emergency or abort routines.  These routines should not call register or aquire.  They shouldn't ask permission to take 
//                     the controls.  Upon calling mcp:abort, no more locks will be issued to any requestors.  Every caller who asks permission to take over any controls
//                     will block in mcp:acquire indefinitely.
////

GLOBAL mcp IS LEXICON(
  "init",                mcp_init@,
  "register",            mcp_register@,
  "requestControl",      mcp_request_control@,
  "haveControl",         mcp_have_control@,
  "release",             mcp_release@,
  "abort",               mcp_abort@,
  "system",              LEXICON(
                           "STEERING", 0,
                           "THROTTLE", 1,
                           "STAGING",  2,
                           "SAS",      3,
                           "RCS",      4,
                           "PARTS",    5,
                           "ORBIT",    6
                         ),
  "priority",            LEXICON(
                           "LOW",    0,
                           "NORMAL", 5,
                           "HIGH",   10
                         ),
  "running",             FALSE,
  "ready",               FALSE,
  "__ticket_db__",       LEXICON(),
  "__mutex_db__",        LIST(),
  "__next_ticket_id__",  0,
  "__local_mutex__",     std:atomic:mutex:init(),
  "__ticket_db_mutex__", std:atomic:mutex:init(),
  "__request_q__",       std:atomic:pqueue:init(),
  "__response_q__",      std:atomic:pqueue:init(),
  "__in_abort__",        FALSE    
).

////
// Initialize the MCP system.  
////
FUNCTION mcp_init {
  SET mcp["__next_ticket_id__"] TO 0.
  FOR idx IN mcp:SYSTEM:VALUES() {
    mcp["__mutex_db__"]:INSERT(idx, std:atomic:mutex:init()).
  }
  
  WHEN NOT std:atomic:pqueue:empty(mcp["__request_q__"]) THEN {
    IF mcp["__in_abort__"] {
      RETURN FALSE.  // From this point forward, all threads which ask permission to access systems will block forever.
    }
    LOCAL request IS std:atomic:pqueue:pop(mcp["__request_q__"]).
    LOCAL ticketId IS request[0].
    LOCAL priority IS request[1].
    LOCAL systemMutexIds IS request[2].
    LOCAL locked IS List().

    PRINT "Processing ressponse for ticketId " + ticketId + ".".
    FOR systemMutex IN systemMutexIds {
      IF std:atomic:mutex:try(systemMutex, 1) {
        locked:ADD(systemMutex).
      } ELSE {
        FOR sysLock in locked {
          std:atomic:mutex:release(sysLock).
        }
        std:atomic:pqueue:push(mcp["__request_q__"], request, priority).
        RETURN TRUE.
      }
    }

    std:atomic:mutex:acquire(mcp["__ticket_db_mutex__"]).
    SET mcp["__ticket_db__"][ticketId] TO systemMutexIds.
    std:atomic:mutex:release(mcp["__ticket_db_mutex__"]).
    std:atomic:pqueue:push(mcp["__response_q__"], ticketId, priority).
    WAIT 0.5.
    RETURN TRUE.
  }
  SET mcp["running"] TO TRUE.
  SET mcp["ready"] TO TRUE.
}

////
// Register a user with the MCP system. A user would be a distinct operation
// or subroutine who might wish to gain control over one of the systems.
// @RETURN - Scalar - An ID which unique identifies the caller.
//// 
FUNCTION mcp_register {
  std:atomic:mutex:acquire(mcp["__local_mutex__"]).
  LOCAL ticketId IS mcp["__next_ticket_id__"].
  SET mcp["__next_ticket_id__"] TO mcp["__next_ticket_id__"] + 1.
  std:atomic:mutex:release(mcp["__local_mutex__"]).
  RETURN ticketId.
}

////
// Put in a request to gain control of the system.  Note, calling this 
// function does give the caller control of the systems yet.  The request
// must be processed and a response must be offered.
// @PARAM - ticketId   - The ID number of the caller provided by mcp:register.
// @PARAM - systemList - A List of mcp:system names that must be exclusively controlled
//                       by the requestor.
// @PARAM - priority   - The priority of the request, taken from mcp:priority. (Default: NORMAL).
// @EXAMPLE
//   SET ticketId TO mcp:register().
//   SET systemList TO List(mcp:system:STEERING, mcp:system:THROTTLE).
//   mcp:requestControl(ticketId, systemList, mcp:priority:HIGH).
////
FUNCTION mcp_request_control {
  PARAMETER ticketId.
  PARAMETER systemList.
  PARAMETER priority IS mcp["priority"]["NORMAL"].

  LOCAL request IS LIST(ticketId, priority).
  LOCAL haveResponse IS FALSE.
  LOCAL systemMutexIds IS LIST().

  FOR systemId IN systemList {
    systemMutexIds:ADD(mcp["__mutex_db__"][systemId]).
  }
  request:ADD(systemMutexIds).
  PRINT "Enqueueing request for ticket ID: " + ticketId + ".".
  std:atomic:pqueue:push(mcp["__request_q__"], request, priority).
  PRINT "Done enqueueing request for ticket ID: " + ticketId + ".".
}

////
// Check and see if the caller's request has been proceed and if
// the caller has been granted control.
// @PARAM  - ticketId - The ID number of the caller provided by mcp:register.
// @RETURN - boolean  - True if your ticketId has control, false otherwise.
// @EXAMPLE
//   SET ticketId TO mcp:register().
//   SET systemList TO List(mcp:system:STEERING, mcp:system:THROTTLE).
//   mcp:requestControl(ticketId, systemList, mcp:priority:HIGH).
//   WAIT UNTIL mcp:haveControl(ticketId).
//   LOCK STEERING TO UP.
////
FUNCTION mcp_have_control {
  PARAMETER ticketId.

  LOCAL haveResponse IS FALSE.
  IF NOT std:atomic:pqueue:empty(mcp["__response_q__"]) {
    IF std:atomic:pqueue:peek(mcp["__response_q__"]) = ticketId {
      PRINT "Have response for ticketId " + ticketId + ".".
      LOCAL discard IS std:atomic:pqueue:pop(mcp["__response_q__"]).
      SET haveResponse TO TRUE.
    }
  }
  RETURN haveResponse.
}

////
// Relenquish control over locked systems.
// @PARAM - ticketId -  The id received from mcp:register.
////
FUNCTION mcp_release {
  PARAMETER ticketId.

  std:atomic:mutex:acquire(mcp["__ticket_db_mutex__"]).
  IF mcp["__ticket_db__"]:HASKEY(ticketId) {
    for mutexId in mcp["__ticket_db__"][ticketId] {
      std:atomic:mutex:release(mutexId).
    }
    mcp["__ticket_db__"]:REMOVE(ticketId).
  }
  std:atomic:mutex:release(mcp["__ticket_db_mutex__"]).
}

////
// Stops the queues from processing.  Any caller which requests
// control of systems, will receive "FALSE" from mcp:haveControl
// indefinitely.
////
FUNCTION mcp_abort {
  SET mcp["__in_abort__"] TO TRUE.
}
