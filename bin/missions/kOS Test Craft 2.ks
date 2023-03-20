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
    PRINT "Doing launch.".
		launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 3, 5, staging:algorithm:flameOut, LIST(6)).
    LOCK STEERING TO PROGRADE.
    PRINT "Launch routine complete.".
	} ELSE IF runstage:stage = 1 {
    PRINT "Creating circulization manuever node.".
		SET newNode TO mnv:node:circularizeApoapsis().
    ADD newNode.
    PRINT "Node created.".
	} ELSE IF runstage:stage = 2 {
    PRINT "Executing circulization node.".
    UNLOCK STEERING.
		mnv:node:do(60, TRUE, 2).
    WAIT 1.
    REMOVE newNode.
    PRINT "Node execution complete.".
  }
  syslog:upload().
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().
