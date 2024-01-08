boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 2.

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
			LIST(5000,   HEADING(90, 70,  180), 1),
			LIST(9500,   HEADING(90, 60,  180), 1),
			LIST(10000,  HEADING(90, 45,  180), 1),
			LIST(13500,  HEADING(90, 40,  180), 1),
			LIST(27000,  HEADING(90, 25,  180), 1),
			LIST(35000,  HEADING(90, 10,  180), 1),
      LIST(40000,  HEADING(90, 10,  225), 1),
      LIST(45000,  HEADING(90, 10,  270), 1),
      LIST(47000,  HEADING(90, 10,  305), 1),
      LIST(50000,  HEADING(90, 10,    0), 1),
			LIST(54000,  HEADING(90, 0,     0), 1),
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

    WHEN (srb:MASS - srb:DRYMASS) / srbPropellantMass < 0.05 AND STAGE:NUMBER = 4 THEN {
      STAGE. RETURN FALSE.
    }
    WHEN SHIP:ORBIT:APOAPSIS >= 300000 OR SHIP:ORBIT:PERIAPSIS >= 30000 THEN {
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
    WHEN math:helper:close(SHIP:BODY:ATM:ALTITUDEPRESSURE(SHIP:ALTITUDE), 0, 0.001) AND SHIP:ALTITUDE >= 280000 THEN {
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
    launch:rocket:go(launchProfile, 300000, FALSE, 0, 5, nullDelegate@, LIST(), launch:profile:offsetTVector@).
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
  }

  syslog:upload().
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().

