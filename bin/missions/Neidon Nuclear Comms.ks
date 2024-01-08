boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 4.

UNTIL runstage:stage > max_runstage {
    IF runstage:stage = 0 {
        launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 1).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(100000).
        ADD rv_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(240, TRUE, FALSE).
        runstage:bump().
    } ELSE IF runstage:stage = 3 {
        SET _depart TO TIMESTAMP(9, 124, 0, 25, 9) + TIMESPAN(SHIP:ORBIT:PERIOD).
        SET _dp_node TO NODE(_depart, 0, -390.6, 2599.6).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 4 {
        mnv:node:do(10, FALSE, FALSE, 0, FALSE).
        runstage:bump().
    }
    runstage:preserve().
    WAIT 1.
}
UNLOCK STEERING.
syslog:shutdown().