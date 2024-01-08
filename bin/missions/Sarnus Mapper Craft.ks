boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

SET profile TO LIST(
//      (altitude, heading, throttle percent)
    LIST(0,      HEADING(90,  90), 1),
    LIST(1000,   HEADING(90,  85), 1),
    LIST(2500,   HEADING(90,  75), 1),
    LIST(5000,   HEADING(90,  65), 1), 
    LIST(7500,   HEADING(90,  55), 1),
    LIST(10000,  HEADING(90,  45), 1),
    LIST(12500,  HEADING(90,  40), 1),
    LIST(15000,  HEADING(90,  35), 1),
    LIST(17500,  HEADING(90,  30), 1),
    LIST(20000,  HEADING(90,  20), 1),
    LIST(25000,  HEADING(90,  10), 1),
    LIST(30000,  HEADING(90,   0), 1),
    LIST(35000,  HEADING(90,  -5), 1),
    LIST(40000,  HEADING(90, -10), 1)
  ).

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 5.

UNTIL runstage:stage > max_runstage {
    IF runstage:stage = 0 {
        launch:rocket:go(profile, 100000, TRUE, 3).
        runstage:bump().
    } ELSE IF runstage:stage = 1 {
        SET rv_node TO mnv:node:setPeriAtApo(100000).
        ADD rv_node.
        runstage:bump().
    } ELSE IF runstage:stage = 2 {
        mnv:node:do(240, TRUE, FALSE).
        runstage:bump().
    } ELSE IF runstage:stage = 3 {
        SET _depart TO TIMESTAMP(9, 184, 0, 0, 0).
        SET _dp_node TO NODE(_depart, 0, 597.7, 2330.1).
        ADD _dp_node.
        runstage:bump().
    } ELSE IF runstage:stage = 4 {
        SET p_reactor TO SHIP:PARTSNAMED("reactor-125")[0].
        SET p_rads TO SHIP:PARTSNAMED("radPanelSm").
        FOR rad IN SHIP:PARTSNAMED("foldingRadMed") {
            p_rads:ADD(rad).
        }
        set m_reactor TO p_reactor:GETMODULE("FissionReactor").
        SET m_rads TO LIST().
        SET me_rads TO LIST().
        FOR rad IN p_rads {
            m_rads:ADD(rad:GETMODULE("ModuleActiveRadiator")).
            if rad:HASMODULE("ModuleDeployableRadiator") {
                me_rads:ADD(rad:GETMODULE("ModuleDeployableRadiator")).
            }
        }
        FOR rad IN me_rads {
            rad:DOACTION("extend radiator", true).
        }
        FOR rad IN m_rads {
            rad:DOACTION("activate radiator", true).
            if rad:HASEVENT("activate radiator") {
                rad:DOEVENT("activate radiator").
            }
        }
        m_reactor:SETFIELD("power setting", 5).
        m_reactor:DOACTION("start reactor", true).
        m_reactor:DOEVENT("start reactor").
        runstage:bump().
    } ELSE IF runstage:stage = 5 {
        mnv:node:do(240, TRUE, FALSE, 0, TRUE).
        runstage:bump().
    }
    runstage:preserve().
    WAIT 1.
}
UNLOCK STEERING.
syslog:shutdown().