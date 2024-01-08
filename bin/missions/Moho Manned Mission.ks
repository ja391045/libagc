boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 4.

SET panelsStowed TO TRUE.
WHEN math:helper:close(SHIP:BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE), 0, 0.001) AND STAGE:NUMBER <= 9 AND panelsStowed THEN {
    WAIT 30.
    SET solarPanels TO parts:solarpanels:getDeployable().
    parts:solarpanels:deploy(solarPanels).
    SET panelsStowed TO FALSE.
    RETURN FALSE.
}

UNTIL runstage:stage > max_runstage {
    IF runstage:stage = 0 {
        launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 9).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(100000).
        ADD rv_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(240, TRUE, FALSE).
        runstage:bump().
    } ELSE IF runstage:stage = 3 {
        SET _depart TO TIMESTAMP(9, 85, 3, 0, 1).
        SET _dp_node TO NODE(_depart, 0, -1071.7, 2482.2).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 4 {
        mnv:node:do(240, TRUE, FALSE, 0, TRUE).
        runstage:bump().
    }
    runstage:preserve().
    syslog:upload().
}
UNLOCK STEERING.
syslog:shutdown().