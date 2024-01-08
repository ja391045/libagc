boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 3.
SET skip_bump TO FALSE.

UNTIL runstage:stage > max_runstage {
  PRINT "Runstage " + runstage:stage + ".".
	IF runstage:stage = 0 {
    PRINT "Doing launch.".
		launch:rocket:go(launch:rocket:default_profile, 285000, TRUE, 3, 5, staging:algorithm:flameOut, LIST(6,5)).
    LOCK STEERING TO PROGRADE.
    PRINT "Launch routine complete.".
  } ELSE IF runstage:stage = 1 {
    SET rv_node TO mnv:node:setPeriAtApo(285000).
    ADD rv_node.
  } ELSE IF runstage:stage = 2 {
    // Execute the burn to rv.
    mnv:node:do(30, TRUE, TRUE, 2).
  } ELSE IF runstage:stage = 3 {
    SET skip_bump TO TRUE.
    SET TARGET TO "Space Station One".
    
    PRINT mnv:rendesvouz:coplanarPhaseAngle().
    WAIT 20.
    CLEARVECDRAWS().
  }
     
  syslog:upload().
  IF NOT skip_bump {
    runstage:bump().
  }
  runstage:preserve().
}
syslog:shutdown().
