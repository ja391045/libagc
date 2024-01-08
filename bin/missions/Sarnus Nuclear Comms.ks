boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 4.

UNTIL runstage:stage > max_runstage {
    IF runstage:stage = 0 {
        launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 1, 5, staging:algorithm:thrustDropOff@, LIST(5, 4, 3)).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(100000).
        ADD rv_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(240, TRUE, FALSE).
        runstage:bump().
    } ELSE IF runstage:stage = 3 {
        SET _one_orbit TO TIMESPAN(SHIP:ORBIT:PERIOD).
        SET _depart TO TIMESTAMP(9, 184, _one_orbit:HOURS, _one_orbit:MINUTES, _one_orbit:SECONDS).
        SET _dp_node TO NODE(_depart, 0, 597.7, 2330.1).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 4 {
        mnv:node:do(240, TRUE, FALSE, 0, TRUE).
        runstage:bump().
    }
    runstage:preserve().
    WAIT 1.
}
UNLOCK STEERING.
syslog:shutdown().