////
// Library of different autostaging alorithms.
////
boot:require("telemetry").
boot:require("syslog").
boot:require("std").
boot:require("math").

GLOBAL staging_algorithm IS LEXICON(
  "thrustDropoff", staging_algorithm_thrust_dropoff@,
  "deltavSpent",   staging_algorithm_deltav_spent@,
  "resourceLeft",  staging_algorithm_resource_left@,
  "flameOut", staging_algorithm_flameout@
).

////
// A simple, but dumb algorithm which decides a stage is called for 
// whenever maximum available thrust drops off.  Note this algorithm won't work
// with things like drop tanks or aspearagus staging.  It's too simple for that.
// @PARAM - buffer   -  A lexicon that the algorithm can use to stash data which must be
//                      persisted between runs.  This algorithm needs to run fast. Type
//                      conformity of the buffer WILL NOT BE CHECKED.
// @RETURN - Boolean -  True if staging is required, false otherwise. 
////
FUNCTION staging_algorithm_thrust_dropoff {
  PARAMETER buffer.
  LOCAL nowThrust IS telemetry:performance:availableThrust().
  LOCAL needStage IS FALSE.
  LOCAL prevThrust IS 0.

  IF buffer:HASKEY("prevThrust") {
    SET prevThrust TO buffer["prevThrust"].
  } else {
    SET prevThrust TO 0.
  }
  IF math:helper:relDiff(nowThrust, 0, 0.01) {
    SET needStage TO TRUE.
  }
  IF nowThrust < prevThrust {
    SET needStage TO TRUE.
  }
  SET buffer["prevThrust"] TO nowThrust.

  IF syslog:logLevel >= syslog:level:DEBUG {
    LOCAL msgData IS LEXICON(
      "prevThrust", prevThrust,
      "nowThrust",   nowThrust
    ).
    LOCAL msgTxt IS std:string:sprintf("Current thrust is ${newThrust}, previous was ${prevThrust}", msgData).
    syslog:msg(msgTxt, syslog:level:debug, "stage:algorithm:thrustDropoff").
  }

  RETURN needStage.
}

////
// When KSP determins that there is zero (or close enough) DeltaV left in the stage, then
// signal that it is time to stage.
// @PARAM  - buffer  - A Lexicon the algorithm cna use to stash persistent values.
// @RETURN - boolean - True if stage is needed, false otherwise.
////
FUNCTION staging_algorithm_deltav_spent {
  PARAMETER buffer.

  IF syslog:logLevel >= syslog:level:DEBUG {
    LOCAL msgTxt IS std:string:sprintf("DeltaV remaining in current stage ${deltav}.", LEXICON("deltav", STAGE:DELTAV)).
    syslog:msg(msgTxt, syslog:level:debug, "stage:algorithm:deltavSpent").
  }

  IF ROUND(STAGE:DELTAV:CURRENT, 2) <= 0.25 {
    RETURN TRUE.
  }
  RETURN FALSE.
}


////
// Stage if any engine in the current stage is flamed out.
////
FUNCTION staging_algorithm_flameout {
  PARAMETER buffer.
  LOCAL stage_engines IS FALSE.
  LOCAL eng IS FALSE.

  LIST ENGINES IN stage_engines.
  FOR eng in stage_engines {
    IF eng:STAGE = STAGE:NUMBER AND eng:IGNITION and eng:FLAMEOUT {
      RETURN TRUE.
    }
  }

  RETURN FALSE.
}

////
// When no resources are available in the current stage for the all the engines in the current stage, return true.
// This algorithm basically doesn't work with solid boosters radially attached if the main engine is also present.
// From the perspective of KSP, it looks like the main engine is in the current stage, but the only fuel tanks in the
// current stage are solid motors.  Probably best to not use.
////

FUNCTION staging_algorithm_resource_left {
  PARAMETER buffer.
  LOCAL rsrc IS FALSE.

  FUNCTION fill_buffer {
    LOCAL l_eng IS LIST().
    LOCAL s_eng IS LIST().
    LOCAL eng IS FALSE.
    LOCAL resource IS FALSE.

    LIST ENGINES in l_eng.

    FOR eng IN l_eng {
      IF eng:STAGE = STAGE:NUMBER {
        FOR resource IN eng:CONSUMEDRESOURCES:VALUES {
          IF s_eng:FIND(resource:NAME) < 0 {
            s_eng:ADD(resource:NAME).
          }
        }
      }
    }
    RETURN LEXICON("stage_resources", s_eng).
  }

  IF NOT buffer:HASKEY("stage_resources") {
    SET buffer TO fill_buffer().
  }

  LOCAL current_rsrcs IS STAGE:RESOURCESLEX:COPY().

  FOR rsrc IN buffer:stage_resources {
    LOCAL msgfmt IS "Checking stage ${stagenum} for resource ${rsrc}:  Amount Left: ${amount}.".
    LOCAL msgdata IS LEXICON(
      "stagenum", STAGE:NUMBER,
      "rsrc", rsrc,
      "amount", "missing."
    ).
    IF current_rsrcs:HASKEY(rsrc) {
      SET msgdata["amount"] TO current_rsrcs[rsrc]:AMOUNT.
      LOCAL sysmsg IS std:string:sprintf(msgfmt, msgdata).
      syslog:msg(sysmsg, syslog:level:debug, "staging:algorithm:resourceLeft").
      IF current_rsrcs[rsrc]:AMOUNT <= 0.25 {
        buffer:REMOVE("stage_resources").
        RETURN TRUE.
      }
    } ELSE {
      LOCAL sysmsg IS std:string:sprintf(msgfmt, msgdata).
      syslog:msg(sysmsg, syslog:level:debug, "staging:algorithm:resourceLeft").
      buffer:REMOVE("stage_resources").
      RETURN TRUE.
    }
  }

  RETURN FALSE.
}
