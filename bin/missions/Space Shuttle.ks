boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 7.

FUNCTION nullDelegate {}

UNTIL runstage:stage > max_runstage {
  PRINT "Runstage " + runstage:stage + ".".
  IF runstage:stage = 0 {
    // Launch Profile.
    SET launchProfile TO LIST(
      LIST(150,    HEADING(90, 90,  270), 1),
      LIST(300,    HEADING(90, 90,  225), 1),
      LIST(500,    HEADING(90, 90,  180), 1), 
      LIST(700,    HEADING(90, 80,  180), 1),
			LIST(9000,   HEADING(90, 75,  180), 1),
			LIST(11500,  HEADING(90, 65,  180), 1),
			LIST(14000,  HEADING(90, 55,  180), 1),
			LIST(16509,  HEADING(90, 45,  180), 1),
			LIST(34000,  HEADING(90, 30,  180), 1),
			LIST(44000,  HEADING(90, 15,  180), 1),
      LIST(45000,  HEADING(90, 15,  225), 1),
      LIST(47000,  HEADING(90, 15,  270), 1),
      LIST(49000,  HEADING(90, 15,  305), 1),
      LIST(51000,  HEADING(90, 15,    0), 1),
			LIST(54000,  HEADING(90, 5,     0), 1),
			LIST(64000,  HEADING(90, 0,     0), 1),
			LIST(100000, HEADING(90, -5,    0), 1)
    ).
    // Setup some things that need to be done.
    // Stage off the SRB's when they are almost out of fuel.
    SET srbs TO parts:engines:findByNameAndStage("Clydesdale", 0).
    SET mainEngines TO parts:engines:findByNameAndStage("SSME", 0).
    SET orbitEngines TO parts:engines:findByNameAndStage("radialLiquidEngine1-2", 0).
    SET srb TO srbs[0].
    SET srbPropellantMass TO srb:WETMASS - srb:DRYMASS.
    parts:engines:lockGimbal(orbitEngines).
    parts:engines:unlockGimbal(mainEngines).
    WHEN (srb:MASS - srb:DRYMASS) / srbPropellantMass < 0.02 AND STAGE:NUMBER = 4 THEN {
      STAGE. RETURN FALSE.
    }
    WHEN SHIP:ORBIT:APOAPSIS >= 285000 OR SHIP:ORBIT:PERIAPSIS >= 30000 THEN {
      UNLOCK THROTTLE.
      LOCK THROTTLE TO 0.
      SET RCS TO TRUE.
      parts:engines:lockGimbal(mainEngines).
      parts:engines:shutdown(mainEngines).
      parts:engines:unlockGimbal(orbitEngines).
      STAGE. // Drop Main Tank.
      LOCK STEERING TO PROGRADE.
      WAIT UNTIL STAGE:READY.
      STAGE.
      UNLOCK THROTTLE.
      parts:startFuelCells(parts:allFuelCells()).
			RETURN FALSE.
		}
    WHEN math:helper:close(SHIP:BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE), 0, 0.001) AND SHIP:ALTITUDE > 70000 THEN {
      SET solarPanels TO parts:solarpanels:getDeployable().
      parts:solarpanels:deploy(solarPanels).
      RETURN FALSE.
    }
    LOCK THROTTLE TO 1.
    LOCK STEERING TO HEADING(0, 90, 0).
    WAIT 5.
    STAGE.
    WAIT UNTIL STAGE:READY.
    STAGE.
    launch:rocket:go(launchProfile, 285000, FALSE, 0, 5, nullDelegate@, LIST(), launch:profile:offsetTVector@).
    LOCK STEERING TO PROGRADE.
    WAIT 30.
    WAIT UNTIL math:helper:close(VANG(SHIP:FACING:FOREVECTOR, SHIP:PROGRADE:FOREVECTOR), 0, 0.25).
    UNLOCK STEERING.
  } ELSE IF runstage:stage = 1 {
    SET newNode TO mnv:node:circularizeApoapsis().
    ADD newNode.
    PRINT "Creating circularization maneuver, need " + newNode:DELTAV:MAG + "m/s.".
  } ELSE IF runstage:stage = 2 {
    PRINT "Executing circularization burn.".
    mnv:node:do(90, TRUE, FALSE, 0).
  } ELSE IF runstage:stage = 3 {
    SET oldRCS TO RCS.
    SET oldSAS TO SAS.
    SET SAS TO FALSE.
    SET RCS TO TRUE.
    LOCK STEERING TO PROGRADE.
    SET drains TO SHIP:PARTSDUBBED("main_drain").
    SET bay TO SHIP:PARTSDUBBED("bay_door").
    SET bayMod TO bay[0]:GETMODULE("ModuleAnimateGeneric").
    bayMod:DOEVENT("open").
    WAIT 1.
    WAIT UNTIL bayMod:GETFIELD("status") <> "Moving...".
    parts:act(drains, "drain", "ModuleResourceDrain").
    WAIT 20.
    bayMod:DOEVENT("close").
    WAIT 1.
    WAIT UNTIL bayMod:GETFIELD("status") <> "Moving...".
    SET RCS TO oldRCS.
    SET SAS TO oldSAS.
    UNLOCK STEERING.
  } ELSE IF runstage:stage = 4 {
    PRINT "Plotting transfer orbit 100km.".
    SET targetSMA TO ((SHIP:ORBIT:BODY:RADIUS * 2) + SHIP:ORBIT:PERIAPSIS + 100000) / 2.
    SET transferNode TO mnv:node:setApoAtPeri(100000).
    ADD transferNode.
    SET newOrbit TO transferNode:ORBIT.
  } ELSE IF runstage:stage = 5 {
    PRINT "Plotting circularization after transfer orbit.".
    SET circularNode TO mnv:node:circularizePeriapsis(newOrbit).
    ADD circularNode.
  } ELSE IF runstage:stage = 6 {
    PRINT "Executing transfer orbit.".
    mnv:node:do(90, TRUE, FALSE, 0).
    WAIT 2.
  } ELSE IF runstage:stage = 7 {
    PRINT "Executing circularization.".
    mnv:node:do(90, TRUE, FALSE, 0).
    WAIT 2.
  }

  syslog:upload().
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().

