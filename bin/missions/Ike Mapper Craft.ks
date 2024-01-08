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
        SET profile TO LIST(
//      (altitude, heading, throttle percent)
            LIST(0,     HEADING(90,  90), 1),
            LIST(200,   HEADING(90,  85), 1),
            LIST(1500,  HEADING(90,  80), 1),
            LIST(5000,  HEADING(90,  75), 1), 
            LIST(7500,  HEADING(90,  60), 1),
            LIST(10000, HEADING(90,  45), 1),
            LIST(15000, HEADING(90,  30), 1),
            LIST(20000, HEADING(90,  15), 1),
            LIST(25000, HEADING(90,   0), 1),
            LIST(35000, HEADING(90,  -5), 1),
            LIST(50000, HEADING(90, -10), 1)
        ).
        launch:rocket:go(profile, 100000, TRUE, 1).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(100000).
        ADD rv_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(90, TRUE, FALSE).
        runstage:bump().
    } ELSE IF runstage:stage = 3 {
        SET _depart TO TIMESTAMP(10, 24, 4, 16, 22).
        SET _dp_node TO NODE(_depart, 0, -133.8, 1054.1).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 4 {
        mnv:node:do(90, FALSE, FALSE, 0, TRUE, staging:algorithm:flameOut, SHIP:FACING:ROLL, 0.4).
        runstage:bump().
    }
    runstage:preserve().
    WAIT 1.
}
UNLOCK STEERING.
syslog:shutdown().