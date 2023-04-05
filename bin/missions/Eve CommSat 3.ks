boot:require("runstage").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:INFO, FALSE).
runstage:load().
SET max_runstage TO 2.
SET skipBump TO FALSE.

UNTIL runstage:stage > max_runstage {
	IF runstage:stage = 0 {
    SET utime TO 62530318 + SHIP:ORBIT:PERIOD + (SHIP:ORBIT:PERIOD * ( 2 / 3 ) ).
    SET firstNode TO mnv:node:modRadiusAt(utime, SHIP:BODY:RADIUS + 705000).
    ADD firstNode.
    WAIT 2.
    SET secondNode TO mnv:node:circularizePeriapsis(firstNode:ORBIT).
    ADD secondNode.
    runstage:bump().
    runstage:preserve().
    BREAK.
	} ELSE IF runstage:stage = 1 {
    mnv:node:do(30, TRUE, FALSE).
    runstage:bump().
    runstage:preserve().
    BREAK.
  } ELSE IF runstage:stage = 2 {
    mnv:node:do(30, TRUE, FALSE).
    runstage:bump().
    runstage:preserve().
    BREAK.
  }
  syslog:upload().
}
syslog:shutdown().
PRINT "Runstages Complete, ran up to " + (runstage:stage - 1)+ " out of " + max_runstage + " stages.".
