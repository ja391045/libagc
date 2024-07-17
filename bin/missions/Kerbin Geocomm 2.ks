boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").
boot:require("parts").
boot:require("math").
boot:require("telemetry").
boot:support("geocomm_comms").


WAIT UNTIL SHIP:STATUS <> "prelaunch" OR SHIP:UNPACKED.

syslog:init(syslog:level:debug, TRUE, PATH("0:/log/" + SHIP:NAME + ".log"), FALSE).
runstage:load().

// Need the messaging system up and running.
comms:vessel:init().
team_register_delegates().
comms:vessel:start().
SET max_runstage TO 12.

// These variables will get used in multiple runstages.

UNTIL runstage:stage > max_runstage {
  WAIT UNTIL std:activeVessel().
  IF SHIP:NAME = "Kerbin Geocomm 2" {
    SET TARGET TO VESSEL("Kerbin Geocomm 1").
  } ELSE IF SHIP:NAME = "Kerbin Geocomm 3" {
    SET TARGET TO VESSEL("Kerbin Geocomm 2").
  }
  SET RCS TO FALSE.
  SET SAS TO FALSE.
  IF runstage:stage = 0 {
    SET launch_time TO mnv:rendesvouz:launchWindow(TARGET, SHIP, SHIP:BODY, 8, 0, 14).
    IF (launch_time - TIME:SECONDS) < 0 {
      PRINT("No launch windows was found with a 14 day period.").
      BREAK.
    }
    SET warp_until TO launch_time:SECONDS - 30.
    KUNIVERSE:TIMEWARP:WARPTO(warp_until).
    WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED AND KUNIVERSE:TIMEWARP:RATE = KUNIVERSE:TIMEWARP:RATELIST[0] AND TIME:SECONDS >= launch_time:SECONDS.
    PRINT("My LAN is " + SHIP:ORBIT:LAN + " target LAN is " + TARGET:ORBIT:LAN + ".").
    runstage:bump().
	} ELSE IF runstage:stage = 1 {
		SET profile TO LIST(
//      (altitude, heading, throttle percent)
            LIST(0,     HEADING(90,  90), 1),
            LIST(200,   HEADING(90,  87), 1),
            LIST(3000,  HEADING(90,  85), 1),
            LIST(5000,  HEADING(90,  80), 1),
            LIST(10000, HEADING(90,  75), 1),
            LIST(15000, HEADING(90,  60), 1),
            LIST(20000, HEADING(90,  45), 1),
            LIST(25000, HEADING(90,  30), 1),
            LIST(35000, HEADING(90,  20), 1),
            LIST(50000, HEADING(90,  10), 1)
        ).

    launch:rocket:go(profile, 2863334, TRUE, 2, 1, staging:algorithm:flameOut@, LIST(3), launch:profile:offsetNull@, 150000).
    WAIT 10.
    // Deploy fairing.
    STAGE. 
    WAIT 15.
    // Separate Upper Stage.
    STAGE.
    runstage:bump().
  } ELSE IF runstage:stage = 2 {
    WAIT UNTIL SHIP:ALTITUDE >= 70000.
    WAIT 15.
    parts:solarpanels:deploy(parts:solarpanels:getDeployable()).
    runstage:bump().
  } ELSE IF runstage:stage = 3 {
    ant_to_target("Kerbin").
    WAIT 15.
    runstage:bump().
  } ELSE IF runstage:stage = 4 {
    SET omniPart TO SHIP:PARTSTAGGED("KerbinOmni")[0].
    Set omniModule TO omniPart:GETMODULE("ModuleRTAntenna").
    omniModule:DOACTION("activate", TRUE).
    SET SHIP:TYPE TO "Relay".
    runstage:bump().
  } ELSE IF runstage:stage = 5 {
    SET _time TO SHIP:ORBIT:ETA:APOAPSIS + TIME:SECONDS.
    SET _node_time TO TIMESPAN(ROUND(SHIP:ORBIT:ETA:APOAPSIS / 2)).
    SET _ca TO mnv:rendesvouz:targetedHillClimb(_time, TARGET, SHIP).
    SET encounter_node TO NODE(_node_time, 0, 0, 0).
    SET encounter_data TO mnv:rendesvouz:nodeWalkIn(encounter_node, _ca["time"]).
    runstage:bump().
  } ELSE IF runstage:stage = 6 {
    mnv:node:do(60, TRUE, FALSE, 0, FALSE).
    runstage:bump().
  } ELSE IF runstage:stage = 7 {
    mnv:rendesvouz:cancelVelocityNoNode(TIME:SECONDS + SHIP:ORBIT:ETA:APOAPSIS).
    runstage:bump().
  } ELSE IF runstage:stage = 8 {
    mnv:rcs:closeIn().
    runstage:bump().
  } ELSE IF runstage:stage = 9 {
    IF TARGET:DISTANCE < 2000 {
	    mnv:rcs:closeIn().
    }
		IF make_node() {
      runstage:bump().
		}
  } ELSE IF runstage:stage = 10 {
    WAIT 1. // Give it some time for TARGET to get repopulated.
    WAIT UNTIL std:activeVessel().
    IF HASNODE AND TARGET:ORBIT:PERIAPSIS > 2860000 {
      IF mnv:node:do(60, TRUE, FALSE, 0, FALSE) {
        runstage:bump().
      }
    }
  } ELSE IF runstage:stage = 11 {
    WAIT 5.
    IF SHIP:NAME = "Kerbin Geocomm 2" {
      SET pv TO VESSEL("Kerbin Geocomm 3").
      IF pv:ORBIT:PERIAPSIS > 2860000 {
        runstage:bump().
      }
    } ELSE {
      runstage:bump().
    }
	} ELSE IF runstage:stage = 12 {
    IF std:activeVessel() {
      LOCK apoClose TO math:helper:close(SHIP:ORBIT:APOAPSIS, 2863334, 0.5).
      LOCK periClose TO math:helper:close(SHIP:ORBIT:PERIAPSIS, 2863334, 0.5).
      SET _rcs_thrusters TO SHIP:PARTSNAMEDPATTERN(".*rcs.*").
      UNTIL apoClose AND periClose {
        IF NOT apoClose {
          WARPTO(TIME:SECONDS + ETA:PERIAPSIS - 60).
          LOCK STEERING TO SHIP:PROGRADE.
          IF ABS(SHIP:ORBIT:APOAPSIS - 2863334)  < 1 {
            SET adj_window TO 6.
          } ELSE {
            SET adj_window TO 12.
          }
          WAIT UNTIL ETA:PERIAPSIS <= adj_window + 1.
          UNLOCK STEERING.
          SET adj_end TO TIME:SECONDS + adj_window.
          WHEN TIME:SECONDS > adj_end THEN {
            mnv:rcs:shortCircuit().
          }
          mnv:rcs:fineApoapsis(2863334, _rcs_thrusters).
        }
        IF NOT periClose {
          WARPTO(TIME:SECONDS + ETA:APOAPSIS - 60).
          LOCK STEERING TO SHIP:PROGRADE.
          IF ABS(SHIP:ORBIT:PERIAPSIS - 2863334) < 1 {
            SET adj_window TO 6.
          } ELSE {
            SET adj_window TO 12.
        }
          WAIT UNTIL ETA:APOAPSIS <= adj_window + 1.
          UNLOCK STEERING.
          SET adj_end TO TIME:SECONDS + adj_window.
          WHEN TIME:SECONDS > adj_end THEN {
            mnv:rcs:shortCircuit().
          }
          mnv:rcs:finePeriapsis(2863334, _rcs_thrusters).
        }
      }
      runstage:bump().
    }
  }
  runstage:preserve().
  syslog:upload(5).
}
syslog:shutdown().
PRINT "Runstages Complete, ran up to " + (runstage:stage - 1)+ " out of " + max_runstage + " stages.".
