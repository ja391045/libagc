boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").
boot:require("parts").

syslog:init(syslog:level:debug, TRUE).
runstage:load().
SET max_runstage TO 4.

UNTIL runstage:stage > max_runstage {
    PRINT "Launch.".
    IF runstage:stage = 0 {
        RCS ON.
        launch:rocket:go(
            launch:rocket:default_profile,
            285000,
            TRUE,
            1
        ).
        WAIT 5.
        RCS OFF.
        WAIT UNTIL SHIP:Q <= 0.1.
        parts:solarpanels:deploy(parts:solarpanels:getDeployable()).
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(285000).
        ADD rv_node.
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(30, TRUE, FALSE, 1, FALSE).
    } ELSE IF runstage:stage = 3 {
        SET first_node TO mnv:node:setApoAtPeri(100000).
        ADD first_node.
        SET second_node TO mnv:node:circularizePeriapsis(first_node:ORBIT).
        ADD second_node.
    } ELSE IF runstage:stage = 4 {
        mnv:node:do(45, TRUE, FALSE, 1, FALSE).
        mnv:node:do(45, TRUE, FALSE, 1, FALSE).
    }
    runstage:bump().
    runstage:preserve().
}