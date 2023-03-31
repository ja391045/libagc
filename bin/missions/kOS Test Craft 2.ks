boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 3.

UNTIL runstage:stage > max_runstage {
  PRINT "Runstage " + runstage:stage + ".".
	IF runstage:stage = 0 {
    PRINT "Doing launch.".
		launch:rocket:go(launch:rocket:default_profile, 285000, TRUE, 3, 5, staging:algorithm:flameOut, LIST(6,5)).
    LOCK STEERING TO PROGRADE.
    PRINT "Launch routine complete.".
  } ELSE IF runstage:stage = 1 {
    SET rv_node TO mnv:node:setPeriAtApo(300000).
    ADD rv_node.
    
    
  } ELSE IF runstage:stage = 2 {
    // Execute the burn to rv.
    mnv:node:do(30, FALSE, TRUE, 2).
  } ELSE IF runstage:stage = 3 {
    mnv:node:do(30, TRUE, TRUE, 2).
  }
  syslog:upload().
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().
