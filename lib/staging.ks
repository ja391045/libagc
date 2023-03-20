boot:require("syslog").
boot:require("mcp").
boot:require("staging/algorithm").
boot:require("std/atomic").

GLOBAL staging_autostage_cancel IS FALSE.

GLOBAL staging IS LEXICON(
  "AUTOSTAGE_ACTIVE", FALSE,
  "algorithm",        staging_algorithm,
  "auto",             staging_auto@,
  "stop",             staging_stop_auto@,
  "doStage",          staging_do_stage@
).

////
// Automatically stage down to and including the specified stage.
// @PARAM - downTo    - The stage number of the last stage to include in the auto stage run. (Default: 0)
// @PARAM - algorithm - The algorithm to use to determine if staging is necessary. (Default: staging:algorithm:deltavSpent).
// @PARAM - coldStart - Ignore output of algorithm, and perform the first stage regardless.  This is useful
//                      when the very first stage is "launch", and no engines are active, etc.
// @PARAM - noSafeStage - Skip safe staging for the stages in the provided list.
////
FUNCTION staging_auto {
  PARAMETER downTo IS 0.
  PARAMETER algorithm IS staging_algorithm_thrust_dropoff@.
  PARAMETER coldStart IS TRUE.
  PARAMETER noSafeStage IS LIST().
  LOCAL buffer IS LEXICON().
  LOCAL msgTxt IS "Autostage configured through stage ".
  LOCAL isSafeStage IS FALSE.

  IF staging:AUTOSTAGE_ACTIVE {
    syslog:msg("Autostage is already in progress, refusing restart.", syslog:level:warn, "staging:auto").
    RETURN.
  }
  SET STAGING:AUTOSTAGE_ACTIVE TO TRUE.

  SET msgTxt TO msgTxt + downTo + ".".
  IF coldStart {
    SET msgTxt TO msgTxt + "  The first stage is a cold start.".
  }
  syslog:msg(msgTxt, syslog:level:info, "staging:auto").

  IF coldStart {
    staging_do_stage(coldStart).
  }
  WAIT 1.

  WHEN algorithm(buffer) OR staging_autostage_cancel THEN {
    IF STAGING:AUTOSTAGE_ACTIVE AND NOT staging_autostage_cancel {
      IF STAGE:NUMBER >= downTo {
        if noSafeStage:FIND(STAGE:NUMBER) < 0 {
          syslog:msg("Safe staging stage " + STAGE:NUMBER + ".", syslog:level:info, "staging:auto").
          SET isSafeStage TO TRUE.
        } else {
          syslog:msg("Staging stage " + STAGE:NUMBER + ".", syslog:level:info, "staging:auto").
          SET isSafeStage TO FALSE.
        }
        staging_do_stage(FALSE, isSafeStage).
        IF STAGE:NUMBER = downTo {
          SET staging["AUTOSTAGE_ACTIVE"] TO FALSE.
        }
      } ELSE {
        SET staging["AUTOSTAGE_ACTIVE"] TO FALSE.
      }
      WAIT 1.
    }
    SET staging_autostage_cancel TO FALSE. // We are canceling it now.
    RETURN staging:AUTOSTAGE_ACTIVE.
  }
}

////
// Stop the autostage watcher.
////
FUNCTION staging_stop_auto {
  SET staging["AUTOSTAGE_ACTIVE"] TO FALSE.
  SET staging_autostage_cancel TO TRUE.
}


////
// Perform a "safe" staging function.
////
FUNCTION staging_do_stage {
  PARAMETER coldStart IS FALSE.
  PARAMETER safeStage IS TRUE.
  LOCAL prevThrottle IS 0.

  syslog:msg("Beginning stage operation.", syslog:level:info, "__staging_do_stage").
  // Gain exclusive control of throttle, staging, and parts.  Parts is only included because
  // parts will disappear during the staging operation, and we don't want other parts of the program to be
  // trying to tweak parts if they are just going to drop off the craft.
  SET prevThrottle TO THROTTLE.
  IF NOT coldStart {
    IF safeStage {
      LOCK THROTTLE TO 0.
      WAIT 0.5.
    }
  }
  STAGE.
  WAIT UNTIL STAGE:READY.
  LOCK THROTTLE TO prevThrottle.
  syslog:msg("Ending stage operation.", syslog:level:info, "__staging_do_stage").
}
