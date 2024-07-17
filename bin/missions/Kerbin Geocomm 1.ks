boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").
boot:require("parts").
boot:require("math").
boot:support("geocomm_comms").


syslog:init(syslog:level:debug, TRUE, PATH("0:/log/" + SHIP:NAME + ".log"), FALSE).
runstage:load().

// We need the messaging system up and running.
comms:vessel:init().
lead_register_callbacks().
lead_register_delegates().
comms:vessel:start().

SET max_runstage TO 14.

UNTIL runstage:stage > max_runstage {
  SET RCS TO FALSE.
  SET SAS TO FALSE.
	IF runstage:stage = 0 {
    WAIT UNTIL std:activeVessel().
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
  } ELSE IF runstage:stage = 1 {
    WAIT UNTIL std:activeVessel() AND SHIP:ALTITUDE >= 70000.
    WAIT 15.
    parts:solarpanels:deploy(parts:solarpanels:getDeployable()).
    runstage:bump().
  } ELSE IF runstage:stage = 2 {
    ant_to_target("Kerbin").
    WAIT 15.
    runstage:bump().
  } ELSE IF runstage:stage = 3 {
    // Get that periapsis precisely to 2,863,334
    SET _rcs_thrusters TO SHIP:PARTSNAMEDPATTERN(".*rcs.*").
    mnv:rcs:fineApoapsis(2863334, _rcs_thrusters).
    runstage:bump().
  } ELSE IF runstage:stage = 4 {
    WAIT UNTIL std:activeVessel().
    SET circ_node TO mnv:node:setPeriAtApo(1222703).
    ADD circ_node.
    runstage:bump().
  } ELSE IF runstage:stage = 5 {
    WAIT UNTIL std:activeVessel().
    mnv:node:do(90, TRUE, FALSE, 0, FALSE).
    runstage:bump().
  } ELSE IF runstage:stage = 6 {
    SET omniPart TO SHIP:PARTSTAGGED("KerbinOmni")[0].
    Set omniModule TO omniPart:GETMODULE("ModuleRTAntenna").
    omniModule:DOACTION("activate", TRUE).
    SET SHIP:TYPE TO "Relay".
    runstage:bump().
  } ELSE IF runstage:stage = 7 {
    WAIT UNTIL std:activeVessel().
    LOCK apoClose TO math:helper:close(SHIP:ORBIT:APOAPSIS, 2863334, 0.5).
    LOCK periClose TO math:helper:close(SHIP:ORBIT:PERIAPSIS, 1222703, 0.5).
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
        IF ABS(SHIP:ORBIT:PERIAPSIS - 1222703) < 1 {
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
        mnv:rcs:finePeriapsis(1222703, _rcs_thrusters).
      }
    }
    runstage:bump().
  } ELSE IF runstage:stage = 8 {
    // Team variable is global in support/geocomm_comms.ks
    SET members_close TO TRUE.
    FOR member IN team {
      IF std:isValidTarget(member) {
        SET mem_vsl TO VESSEL(member).
        IF mem_vsl:DISTANCE > 100 {
          SET members_close TO FALSE.
        }
      } ELSE {
        SET members_close TO FALSE.
      }
    }
    IF members_close {
      runstage:bump().
    } ELSE {
      WAIT 10.
    }
  } ELSE IF runstage:stage = 9 {
    IF NOT lead_set_antennas() {
      PRINT("Waiting for set antennas to succeed.").
      WAIT 5.
    } ELSE {
      runstage:bump().
    }
  } ELSE IF runstage:stage = 10 {
    IF NOT lead_set_manuevers() { 
      PRINT("Waiting for set manuevers command to succeed.").
      WAIT 5.
    } ELSE {
      runstage:bump().
    }
  } ELSE IF runstage:stage = 11 {
    WAIT UNTIL std:activeVessel().
    lead_set_my_mnv().
    runstage:bump().
  } ELSE IF runstage:stage = 12 {
    WAIT UNTIL std:activeVessel().
    IF mnv:node:do(90, TRUE, FALSE, 0, FALSE) {
      runstage:bump().
    }
  } ELSE IF runstage:stage = 13 {
    WAIT 5.
    SET pv TO VESSEL("Kerbin Geocomm 3").
    IF pv:ORBIT:PERIAPSIS > 2860000 {
      runstage:bump().
    }
  } ELSE IF runstage:stage = 14 {
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
