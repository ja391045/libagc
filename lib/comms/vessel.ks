////
// Inter-vessel communication libraries.
// If your vessel is going to use this library, it must call init toward the top of the bin/missions script, after the vessel is fully loaded,
// and it should call shutdown before the bin script exits completely.   Any sort of on_message delegates should be setup before "start" is called.
////

boot:require("std").
boot:require("syslog").

GLOBAL comms_vessel IS LEXICON(
  "init",               comms_vessel_init@,
  "start",              comms_vessel_start@,
  "shutdown",           comms_vessel_shutdown@,
  "send",               comms_vessel_send@,
  "addCallback",        comms_vessel_add_callback@,
  "removeCallback",     comms_vessel_remove_callback@,
  "addDelegate",        comms_vessel_add_delegate@,
  "removeDelegate",     comms_vessel_remove_delegate@,
  "__vol__",            VOLUME(1),
  "__in__",             std:atomic:pqueue:init(),
  "__out__",            std:atomic:pqueue:init(),
  "__delegates__",      LEXICON(),
  "__callbacks__",      LEXICON(),
  "__init__",           FALSE,
  "__start__",          FALSE,
  "__in_run__",         FALSE,
  "__out_run__",        FALSE,
  "__topdir__",         "/msg",
  "__in_file__",        "in_queue.json",
  "__out_file__",       "out_queue.json",
  "__del_key_cache__",  LIST(),
  "__call_key_cache__", LIST(),
  "rc",                 LEXICON(
    "success",          0,
    "enotarget",        1,
    "enoconn",          2,
    "eunknown",         3
  )
).

////
// Initialize messaging infrastructure.  Read any stored messages into their proper inbound or outbound queue.
////
FUNCTION comms_vessel_init {
  SWITCH TO comms_vessel["__vol__"].

  IF comms_vessel["__vol__"]:EXISTS(comms_vessel["__topdir__"]) {
    IF comms_vessel["__vol__"]:EXISTS(infile_path) {
      LOCAL data IS READJSON(infile_path).
      SET comms_vessel["__in__"] TO std:atomic:pqueue:init(data).
    }
    IF comms_vessel["__vol__"]:EXISTS(comms_vessel["__out_file__"]) {
      LOCAL data IS READJSON(outfile_path).
      SET comms_vessel["__out__"] TO std:atomic:pqueue:init(data).
    }
  }
  comms_vessel_add_callback("zzzzRetry", comms_vessel_match_all@, comms_vessel_retry_callback@).
  comms_vessel_add_delegate("zzzzLog", comms_vessel_match_all@, comms_vessel_syslog_delegate@).
  SET comms_vessel["__init__"] TO TRUE.
}

////
// Start message processing.  It would be wise to have inbound "onMessage" delegates and matchers setup before calling this.
// In your bin/mission/ file, at the top, init the message system.  Register any notifiers or onMessage delegates.  Then call 
// this function to start the processing.
////
FUNCTION comms_vessel_start {
  IF NOT comms_vessel["__init__"] {
    comms_vessel_init().
  }

  SET comms_vessel["__start__"] TO TRUE.

  WHEN NOT SHIP:MESSAGES:EMPTY THEN {
    _comms_vessel_copy_in().
    IF NOT SHIP:MESSAGES:EMPTY { WAIT 1. }
    RETURN comms_vessel["__start__"].
  }

  WHEN NOT std:atomic:pqueue:empty(comms_vessel["__in__"]) THEN {
    _comms_vessel_process_in().
    IF NOT std:atomic:pqueue:empty(comms_vessel["__in__"]) { WAIT 1. }
    RETURN comms_vessel["__start__"].
  }

  WHEN NOT std:atomic:pqueue:empty(comms_vessel["__out__"]) THEN {
    _comms_vessel_process_out().
    IF NOT std:atomic:pqueue:empty(comms_vessel["__out__"]) { WAIT 1. }
    RETURN comms_vessel["__start__"].
  }
}

////
// Shutdown the message system.  Stop processing of inbound and outbound queues, write the messages leftover and unprocess in the inbound
// and outbound queues to disk.
////
FUNCTION comms_vessel_shutdown {
  SWITCH TO comms_vessel["__vol__"].

  SET comms_vessel["__init__"] TO FALSE.
  SET comms_vessel["__start__"] TO FALSE.
  WAIT UNTIL NOT comms_vessel["__in_run__"] AND NOT comms_vessel["__out_run__"].

  IF NOT comms_vessel["__vol__"]:EXISTS(comms_vessel["__topdir__"]) {
    comms_vessel["__vol__"]:CREATEDIR(comms_vessel["__topdir__"]).
  }

  LOCAL data IS std:atomic:pqueue:foundation(comms_vessel["__in__"]).
  WRITEJSON(data, infile_path).
  SET data TO std:atomic:pqueue:foundation(comms_vessel["__out__"]).
  WRITEJSON(data, outfile_path).
}

////
// Send a message.
// @PARAM _message     - The message to send.  It must have "destination" in it's headers.
// @PARAM _destination - The destination for this message.  This will be set in the headers as destination.
// @PARAM _priority    - The priority for this message.  An integer between 0 and 9, with 9 being the highest. (Default: 0).
//                       This will be set in the headers as priority.
//                    
////
FUNCTION comms_vessel_send {
  PARAMETER _message.
  PARAMETER _destination.
  PARAMETER _priority IS 0.

  std:struct:message:setHeader("destination", _destination, _message).
  std:struct:message:setHeader("priority", _priority, _message).
  std:atomic:pqueue:push(comms_vessel["__out__"], _message, _priority).
}

////
// Add a callback.  Callbacks are invoked when a message send attempt occurs.  There are two parts to a callback, a matcher delegate, and
// the callback delegate.  Matcher delegates are expected to accept the message's headers as parameters and return either TRUE or FALSE, indicating
// that the callback should be invoked for the message. Callback delegates are expected to accept the entire message, a boolean for send status, and
// an error code as parameters.  They should return a boolean value.  If true, further callbacks will be evaluated, if false they will not.  See 
// comms_vessel_match_all and comms_vessel_retry_callback for more details.
// (Hint:  One can use the natural order of _id to control the order callbacks will execute on a matched message).
// @PARAM id       - A human readable reference to this callback.
// @PARAM matcher  - A function reference as described above which returns TRUE or FALSE.  See comms_vessel_match_all.
// @PARAM callback - A processor delegate to be run on this message.  See comms_vessel_retry_callback.
////
FUNCTION comms_vessel_add_callback {
  PARAMETER _id.
  PARAMETER _matcher.
  PARAMETER _callback.

  SET comms_vessel["__callbacks__"][_id] TO LIST(_matcher, _callback).
  SET comms_vessel["__call_key_cache__"] TO comms_vessel["__callbacks__"]:KEYS.
  std:list:mergeSort(comms_vessel["__call_key_cache__"]).
}

////
// Remove a callback.
// @PARAM _id - The id of the callback to remove.
// @RETURN - TRUE if the _id existed in the callback database, FALSE otherwise.
////
FUNCTION comms_vessel_remove_callback {
  PARAMETER _id.

  IF comms_vessel["__callbacks__"]:HASKEY(_id) {
    comms_vessel["__callbacks__"]:REMOVE(_id).
    comms_vessel["__call_key_cache__"]:REMOVE(comms_vessel["__call_key_cache__"]:FIND(_id)).
    RETURN TRUE.
  }
  RETURN FALSE.
}

////
// Add a delegate for inbound message processing.  An delegate consists of a matcher delegate, and a processor delegate.  Very similiar to a callback
// for outbound messages, these delegates work on inbound messages.  The matcher receives as a parameter the headers of a message, and returns TRUE or FALSE.
// If the matcher returns true, then the delegate is invoked and recieves as a parameter the message.  See comms_vessel_match_all and comms_vessel_retry_delegate
// for example.  (Hint:  One can use the natural order of _id to control the order delegates will execute on a matched message).
// @PARAM _id       - A human readable ID for this delegate.
// @PARAM _matcher  - The matcher delegate.
// @PARAM _delegate - The processor delegate.
////
FUNCTION comms_vessel_add_delegate {
  PARAMETER _id.
  PARAMETER _matcher.
  PARAMETER _delegate.

  SET comms_vessel["__delegates__"][_id] TO LIST(_matcher, _delegate).
  SET comms_vessel["__del_key_cache__"] TO comms_vessel["__delegates__"]:KEYS.
  std:list:mergeSort(comms_vessel["__del_key_cache__"]).
}

////
// Remove a previously registered delegate.
// @PARAM _id - The id of the delegate to remove.
// @RETURN - TRUE if a delegate with the given ID was found and removed, FALSE otherwise.
////
FUNCTION comms_vessel_remove_delegate {
  PARAMETER _id.

  IF comms_vessel["__delegates__"]:HASKEY(_id) {
    comms_vessel["__delegates__"]:REMOVE(_id).
    comms_vessel["__del_key_cache__"]:REMOVE(comms_vessel["__del_key_cache__"]:FIND(_id)).
    RETURN TRUE.
  }
  RETURN FALSE.
}

////
// Default matchers, delegates and callbacks are below.
////

// Match any message, no matter what.
FUNCTION comms_vessel_match_all {
  PARAMETER _headers.

  RETURN TRUE.
}

// Retry the send operation a number of times if failed.  This is registered by default at the bottom of the order.
FUNCTION comms_vessel_retry_callback {
  PARAMETER _success.
  PARAMETER _rc_code.
  PARAMETER _message.

  LOCAL dest IS std:struct:message:getHeader("destination", _message).
  LOCAL max_retry IS 5.

  IF _success {
    syslog:msg("Message sent to " + dest + " successfully.", syslog:level:info, "<comms_vessel_retry_callback>").
    RETURN TRUE.
  }

  LOCAL retries IS 0.
  LOCAL _status IS "no more retries, dropping.".

  IF std:struct:message:hasHeader("retries", _message) {
    SET retries TO std:struct:message:getHeader("retries").
  }

  IF retries < max_retry {
    SET retries TO retries + 1.
    SET _status TO (max_retry - retries):TOSTRING + " more retries remaining, resending.".
    LOCAL dest IS std:struct:message:getHeader("destination", _message).
    LOCAL prio IS std:struct:message:getHeader("priority", _message).
    comms:vessel:send(_message, dest, prio).    
  } 

  LOCAL errstr IS "An unknown error occured.".
  IF _rc_code = comms_vessel:rc:enotarget {
    SET errstr TO "Cannot find target " + std:struct:message:getHeader("destination", _message) + ", " + _status.
  } ELSE IF _rc_code = comms_vessel:rc:enoconn {
    SET errstr TO "Cannot connect to target " + std:struct:message:getHeader("destination", _message) + ", " + _status.
  }

  syslog:msg(errstr, syslog:level:error, "<comms_vessel_retry_callback>").
  RETURN FALSE.
}

// Log the received message.  This is registered by default at the bottom of the order with comms_vessel_match_all.
FUNCTION comms_vessel_syslog_delegate {
  PARAMETER _message.

  IF syslog:logLevel >= syslog:level:trace {
    syslog:msg(
      "Message received " + std:struct:message:getPayload(_message):TOSTRING + ".  Headers " + _message["headers"]:TOSTRING + ".",
      syslog:level:trace,
      "<comms_vessel_syslog_delegate"
    ).
  }
  RETURN TRUE.
}


////
// internal api below.
////

// Process the in queue.
FUNCTION _comms_vessel_process_in {
  PARAMETER _max_process IS 5.

  LOCAL processed IS 0.
  SET comms_vessel["__in_run__"] TO TRUE.
  UNTIL std:atomic:pqueue:empty(comms_vessel["__in__"]) OR processed = _max_process OR NOT comms_vessel["__start__"] {
    LOCAL msg IS std:atomic:pqueue:pop(comms_vessel["__in__"]).
    LOCAL key IS FALSE.

    FOR key IN comms_vessel["__del_key_cache__"] {
      LOCAL pair IS comms_vessel["__delegates__"][key].
      IF pair[0](msg["headers"]) {
        IF NOT pair[1](msg) { BREAK. }
      }
    }
    SET processed TO processed + 1.
  }
  SET comms_vessel["__in_run__"] TO FALSE.
}

// Process the out queue.
FUNCTION _comms_vessel_process_out {
  PARAMETER _max_process IS 5.

  LOCAL processed IS 0.
  SET comms_vessel["__out_run__"] TO TRUE.
  LOCAL tgts IS FALSE.
  UNTIL std:atomic:pqueue:empty(comms_vessel["__out__"]) OR processed = _max_process OR NOT comms_vessel["__start__"] {
    LOCAL msg IS std:atomic:pqueue:pop(comms_vessel["__out__"]).
    LOCAL dest IS std:struct:message:getHeader("destination", msg).
    LOCAL rc is comms_vessel:rc:enotarget.
    LOCAL success IS FALSE.
    LIST TARGETS IN tgts.

    IF dest:ISTYPE("VESSEL") { SET dest TO dest:NAME. }

    FOR tgt IN tgts {
      syslog:msg("Comparing target name " + tgt:NAME + " to " + dest + ".", syslog:level:trace, "comms:vesel:_comms_vessel_process_out").
      IF (tgt:NAME = dest) { 
        SET rc TO comms_vessel:rc:enoconn.
        IF tgt:CONNECTION:ISCONNECTED {
          SET rc TO comms_vessel:rc:eunknown.
          IF tgt:CONNECTION:SENDMESSAGE(msg) {
            SET rc TO comms_vessel:rc:success.
            SET success TO TRUE.
          }
        }
        BREAK.
      }
    }

    FOR key IN comms_vessel["__call_key_cache__"] {
      LOCAL pair IS comms_vessel["__callbacks__"][key].
      IF pair[0](msg["headers"]) {
        IF NOT pair[1](success, rc, msg) { BREAK. }.
      }
    }
    SET processed TO processed + 1.
  }
  SET comms_vessel["__out_run__"] TO FALSE.
}

// Copy vessel in-queue to priority queue.
FUNCTION _comms_vessel_copy_in {
  PARAMETER _max_process IS 10.

  LOCAL processed IS 0.
  UNTIL SHIP:MESSAGES:EMPTY() OR processed = _max_process {
    LOCAL msg_wrap IS SHIP:MESSAGES:POP().
    LOCAL msg IS msg_wrap:CONTENT.
    LOCAL sndr IS msg_wrap:SENDER.
    IF sndr:ISTYPE("Vessel") {
      SET sndr TO sndr:NAME.
    }
    std:struct:message:setHeader("sender", sndr, msg).
    std:struct:message:setHeader("sent_at", msg_wrap:SENTAT, msg).
    std:struct:message:setHeader("received_at", msg_wrap:RECEIVEDAT, msg).
    LOCAL priority IS 0.
    IF std:struct:message:hasHeader("priority", msg) {
      SET priority TO std:struct:message:getHeader("priority", msg).
    }
    std:atomic:pqueue:push(comms_vessel["__in__"], msg, priority).
    SET processed TO processed + 1.
  }
}
