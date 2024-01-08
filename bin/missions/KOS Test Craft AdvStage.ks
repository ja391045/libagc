boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 4.
SET skip_bump TO FALSE.

UNTIL runstage:stage > max_runstage {
	IF runstage:stage = 0 {
		launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 2, 5, staging:algorithm:thrustDropOff, LIST(3)).
    WAIT UNTIL SHIP:ALTITUDE > 70000.
    runstage:bump().
  } ELSE IF runstage:stage = 1 {
    SET rv_node TO mnv:node:setPeriAtApo(100000).
    ADD rv_node.
    runstage:bump().
  } ELSE IF runstage:stage = 2 {
    // Execute the burn to rv.
    mnv:node:do(30, TRUE, FALSE).
    runstage:bump().
  } ELSE IF runstage:stage = 3 {
    SET _eta TO TIMESPAN(0, 0, 0, 10, 0).
    SET _depart TO TIME:SECONDS + _eta:SECONDS.
    SET _dp_node TO NODE(_depart, 0, 651.4, 3483.8).
    ADD _dp_node.
    runstage:bump().
  } ELSE IF runstage:stage = 4 {
    mnv:node:do().
  }

  syslog:upload().
  runstage:preserve().
}
