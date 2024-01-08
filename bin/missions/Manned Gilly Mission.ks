boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 2.

SET profile TO LIST(
//      (altitude, heading, throttle percent)
    LIST(0,     HEADING(90, 90), 1),
    LIST(1000,  HEADING(90, 85), 1),
    LIST(4000,  HEADING(90, 80), 1),
    LIST(6000,  HEADING(90, 75), 1), 
    LIST(8000,  HEADING(90, 65), 1),
    LIST(10000, HEADING(90, 55), 1),
    LIST(15000, HEADING(90, 45), 1),
    LIST(20000, HEADING(90, 30), 1),
    LIST(25000, HEADING(90, 20), 1),
    LIST(30000, HEADING(90, 10), 1),
    LIST(35000, HEADING(90,  0), 1),
    LIST(40000, HEADING(90,  -5), 1),
    LIST(50000, HEADING(90, -10), 1)
).

UNTIL runstage:stage > max_runstage {
    IF runstage:stage = 0 {
        launch:rocket:go(profile, 285000, TRUE, 4, 5, staging:algorithm:thrustDropOff@).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET _depart TO TIMESTAMP(10, 38, 1, 39, 28).
        SET _dp_node TO NODE(_depart, 0,-896.8, 1002.5).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(240, TRUE, FALSE, 0, TRUE).
        runstage:bump().
    }
    runstage:preserve().
    WAIT 1.
}
UNLOCK STEERING.
syslog:shutdown().