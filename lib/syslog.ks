boot:require("std").

GLOBAL syslog IS LEXICON(
    "init",      syslog_init@,
    "shutdown",  syslog_shutdown@,
    "msg",       syslog_msg@,
    "upload",    syslog_upload@,
    "level",     LEXICON(
      "crit",  0,
      "error", 1,
      "warn",  2,
      "info",  3,
      "debug", 4,
      "trace", 5
    ),
    "logLevel",  0,
    "__cache__", QUEUE(),
    "__ready__", FALSE,
    "__upload__", FALSE,
    "__echo__", FALSE,
    "__rotate__", TRUE
).


////
// @API: private
// Format a line of syslog.
// @PARAM - message  - The message to log.
// @PARAM - level    - The log level of the message from syslog:level.
// @PARAM - facility - Slightly different than syslog.h, really just a string to identifiy 
////                   the software component doing the logging. (Default: system).
FUNCTION _syslog_linefmt {
    PARAMETER message.
    PARAMETER level.
    PARAMETER facility IS "system".

    LOCAL format IS "[${calendar} ${clock}] <${facility}:${level}>:  ${message}".

    IF level < 0 {
      SET level to 0.
    } ELSE IF level > syslog:level:LENGTH - 1 {
      SET level TO syslog:level:LENGTH - 1.
    }

    LOCAL lvl IS syslog:level:KEYS().
    LOCAL data is LEXICON(
        "calendar", TIME:CALENDAR,
        "clock"   , TIME:CLOCK,
        "message" , message,
        "facility", facility,
        "level"   , lvl[level]
    ).

    RETURN std:string:sprintf(format, data).
}

////
// @API: private
// Rotate the log.
////
FUNCTION _syslog_rotate {
  LOCAL curFh IS PATH(syslog["__path__"]):VOLUME:OPEN(syslog["__path__"]).
  LOCAL curCont IS curFh:READALL.
  LOCAL newQueue IS QUEUE().
  LOCAL startIdx IS MAX(curCont:LENGTH - syslog["__rotate_keep__"], 0).
  LOCAL rotateMark TO "------------- Syslog Rotate Mark -------------".
  SET byteCount TO rotateMark:LENGTH.
  
  newQueue:PUSH(rotateMark).

  FOR line IN curCont {
    IF startIdx <= 0 { newQueue:PUSH(line). }.
    SET startIdx TO startIdx - 1.
    SET byteCount TO byteCount + line:LENGTH.
  }

  IF byteCount < syslog["__max_log_size__"] {
    UNTIL syslog["__cache__"]:EMPTY {
      newQueue:PUSH(syslog["__cache__"]:POP()).
    }
  }

  SET syslog["__cache__"] TO newQueue.
  syslog["__file__"]:CLEAR.
}


////
// @API: private
// Process the syslog cache, writing the lines out to the file, up to max items.
// @PARAM - maxProcess - The maximum number of messages to write out to the file at
//                       this time.  Normally this number should be relatively low
//                       so the trigger calling this function doesn't eat up too many
//                       CPU cycles.  (Default: 5)
////
FUNCTION _syslog_process_queue {
  PARAMETER maxProcess IS 5.

  LOCAL processed IS 0.

  UNTIL syslog["__cache__"]:EMPTY OR processed >= maxProcess {
    IF syslog["__file__"]:SIZE >= syslog["__max_log_size__"] AND syslog["__rotate__"] {
      _syslog_rotate().
    }
    LOCAL current IS syslog["__cache__"]:pop().
    IF syslog:logLevel >= current[0] {
      syslog["__file__"]:writeln(current[1]).
      IF syslog["__echo__"] {
        PRINT current[1].
      }
    }
    SET processed TO processed + 1.
  }
}

////
// Initialize the syslog subsystem.
// @PARAM - logLevel    - The log level for the system. Any messages of log level lower will 
//                        will be discarded. (Default: syslog:level:crit)
// @PARAM - echo        - Also echo syslog to STDOUT.
// @PARAM - destination - The log file destination, can be PATH or String. (Default: 1:/log/messages)
// @PARAM - autoRotate  - Automatically rotate logs to prevent disk space starvation? (Default: TRUE)
// @PARAM - maxLogSize  - The maximum size of the log in bytes, defaults to 1/2 the size of the destination volume,
//                        it has a minimum size of 4096.  Any size given < 4096 will be ignored in lieu of 4096.
// @PARAM - rotateKeep  - The number of messages to keep when log file is rotated. If the kept number of messages is
//                        > maxLogSize, none will be kept. (Default: 50)  This will almost certainly be the case when
//                        if you go to minsize of 4096 and keep 50 lines.   
//// 
FUNCTION syslog_init {
    PARAMETER logLevel IS syslog:level:crit.
    PARAMETER echo IS FALSE.
    PARAMETER destination IS PATH("1:/log/messages").
    PARAMETER autoRotate IS TRUE.
    PARAMETER maxLogSize IS -1.
    PARAMETER rotateKeep IS 50.

    SET syslog["__rotate__"] TO autoRotate.
    SET syslog:logLevel TO logLevel.
    // If syslog has been previously initialized, flush the message queue.
    IF syslog:HASKEY("__file__") {
      _syslog_process_queue(syslog["__cache__"]:LENGTH).
    }
    SET syslog["__upload__"] TO FALSE.
    SET syslog["__echo__"] TO echo.

    IF destination:ISTYPE("String") {
        SET pDest to PATH(destination).
    } ELSE IF destination:ISTYPE("Path") {
        SET pDest TO destination.
    } ELSE { 
        SET errno TO 200.
        RETURN FALSE.
    }

    SET syslog["__auto_rotate__"] TO autoRotate.
    SET syslog["__rotate_keep__"] TO rotateKeep.

    IF maxLogSize <= 0 {
      SET syslog["__max_log_size__"] TO pDest:VOLUME:CAPACITY * .2.
    } ELSE IF maxLogSize < 4096 {
      SET syslog["__max_log_size__"] TO 4096.
    } ELSE {
      SET syslog["__max_log_size__"] TO maxLogSize.
    }

    // Assume last element of destination is the filename.
    LOCAL mkdir IS List().
    FOR segment IN pDest:PARENT:SEGMENTS {
      mkdir:ADD(segment).
      LOCAL _mkdir_string IS mkdir:JOIN("/").
      IF NOT pDest:VOLUME:EXISTS(_mkdir_string) {
        pDest:VOLUME:CREATEDIR(_mkdir_string).
      }
    }

    
    LOCAL fullPath IS pDest:SEGMENTS:JOIN("/").
    IF NOT pDest:VOLUME:EXISTS(fullPath) {
      pDest:VOLUME:CREATE(fullPath).
    }
    SET syslog["__path__"] TO pDest:TOSTRING.
    SET syslog["__file__"] TO pDest:VOLUME:OPEN(fullPath).
    syslog["__file__"]:READALL().

    SET syslog["__ready__"] TO TRUE.
    WHEN NOT syslog["__cache__"]:EMPTY() THEN {
      WAIT UNTIL NOT syslog["__upload__"].
      IF syslog["__ready__"] {
        _syslog_process_queue().
      }
      RETURN syslog["__ready__"].
    }
}


////
// Push a message into the syslog cache so it can be written to disk.
// @PARAM - message  - The message to log.
// @PARAM - logLevel - The log level of the message, one of syslog:level. (Default: syslog:level:crit)
// @PARAM - facility - A string identifying which component is logging the message. (Default: system)
////
FUNCTION syslog_msg {
    PARAMETER message.
    PARAMETER logLevel IS syslog:level:crit.
    PARAMETER facility IS "system".

    IF syslog["__ready__"] {
      LOCAL line IS _syslog_linefmt(message, logLevel, facility).
      LOCAL element IS List(logLevel, line).
      syslog["__cache__"]:PUSH(element).
    }
}

////
// Nicely shutdown the syslog system, ensuring that the cache is flushed to disk
// before exiting.
////
FUNCTION syslog_shutdown {
  SET syslog["__ready__"] TO FALSE.
  _syslog_process_queue(syslog["__cache__"]:LENGTH).
}

////
// Upload syslog to KSC volume on demand.  We can't assume this is successful,
// because it could time out waiting on connection.  This method will block until
// timeout.
// @PARAMETER timeout - How long to wait for a connection and upload until giving up.
////
FUNCTION syslog_upload {
  PARAMETER timeout IS 30.

  PRINT "Uploading " + syslog["__path__"] + ".".
  LOCAL ksc_log_dst IS PATH("0:/log/" + SHIP:NAME + ".log").
  LOCAL tm_out IS TIME:SECONDS + timeout.
  LOCAL done IS FALSE.
  LOCAL success IS FALSE.

  IF ksc_log_dst:TOSTRING = syslog["__path__"]:TOSTRING { PRINT "Done". RETURN TRUE. }.

  UNTIL done {
    IF HOMECONNECTION:ISCONNECTED {
      SET syslog["__upload__"] TO TRUE.
      COPYPATH(syslog["__path__"], ksc_log_dst).
      SET syslog["__upload__"] TO FALSE.
      SET success to TRUE.
      SET done TO TRUE.
    } ELSE {
      IF TIME:SECONDS > tm_out {
        SET done TO TRUE.
      }
      WAIT 1.
    }
  }
  PRINT "Upload Done.".
  RETURN success.
}
