boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 2.

UNTIL runstage:stage > max_runstage {
  PRINT "Runstage " + runstage:stage + ".".
	IF runstage:stage = 0 {
    mnv:node:do(60, FALSE).
  } ELSE IF runstage:stage = 1 {
    mnv:node:do(60, FALSE).
  }
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().
