boot:require("runstage").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:INFO, FALSE).
runstage:load().
SET max_runstage TO 0.
SET skipBump TO FALSE.

UNTIL runstage:stage > max_runstage {
	IF runstage:stage = 0 {

	}
  syslog:upload().
  IF NOT skipBump {
    runstage:bump().
  }
  runstage:preserve().
  IF skipBump { BREAK. }.
}
syslog:shutdown().
PRINT "Runstages Complete, ran up to " + (runstage:stage - 1)+ " out of " + max_runstage + " stages.".
