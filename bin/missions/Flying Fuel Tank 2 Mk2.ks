boot:require("runstage").
boot:require("syslog").
boot:require("telemetry").
boot:require("launch").
boot:require("mnv").
boot:require("parts").
boot:require("std").

syslog:init(syslog:level:info, TRUE).
runstage:load().
SET max_runstage TO 2.

FUNCTION nullDelegate {}

UNTIL runstage:stage > max_runstage {
  PRINT "Runstage " + runstage:stage + ".".
  IF runstage:stage = 0 {
    // Launch Profile.
    SET launchProfile TO LIST(
      LIST(0,      HEADING(90, 10, 0), 1),
      LIST(10000,  HEADING(90, 15, 0), 1),
      LIST(24000,  HEADING(90, 10, 0), 1)
    ).
    // Setup some things that need to be done.
    // Stage off the SRB's when they are almost out of fuel.
    WAIT UNTIL STAGE:READY.
    SET BRAKES TO TRUE.
    SET mainEngines TO parts:engines:findByNameAndStage("RAPIER", 0).
    SET srbs TO parts:engines:findByNameAndStage("solidBooster1-1", 2).
    SET rollControllers TO SHIP:PARTSNAMED("elevon2").
    SET pitchControllers TO SHIP:PARTSNAMED("elevon3").
    SET yawControllers TO SHIP:PARTSNAMED("TailFin").
    SET tmpControllers TO std:list:concat(rollControllers, pitchControllers).
    SET controlSurfaces TO std:list:concat(tmpControllers, yawControllers).
    LOCK THROTTLE TO 1.
    WHEN srbs[0]:MASS <= srbs[0]:DRYMASS THEN {
      STAGE.
    }
    WHEN SHIP:ALTITUDE >= 21000 AND telemetry:performance:averageThrust() < 50 THEN {
      parts:engines:swapMode(mainEngines).
    }
    WHEN SHIP:ALTITUDE > 70000 THEN {
      parts:controlsurfaces:lockAll(controlSurfaces).
      parts:solarpanels:deploy(parts:solarpanels:getDeployable()).
    }
    WAIT 5.
    LOCK STEERING TO HEADING(90, 0, 0).
    STAGE.
    SET BRAKES TO FALSE.
    WAIT UNTIL SHIP:GROUNDSPEED >= 200.
    LOCK STEERING TO HEADING(90, 10, 0).
    WAIT UNTIL SHIP:ALTITUDE >= 80 OR SHIP:AIRSPEED >= 250.
    SET GEAR TO FALSE.
    WAIT UNTIL telemetry:performance:averageThrust() > 340.
    launch:rocket:go(launchProfile, 285000, FALSE).
    WAIT UNTIL SHIP:ALTITUDE > 70000.
    LOCK STEERING TO PROGRADE.
    WAIT 10.
    WAIT UNTIL math:helper:close(VANG(SHIP:FACING:FOREVECTOR, SHIP:PROGRADE:FOREVECTOR), 0, 0.25).
  } ELSE IF runstage:stage = 1 {
    SET newNode TO mnv:node:circularizeApoapsis().
    ADD newNode.
    PRINT "Creating circularization maneuver, need " + newNode:DELTAV:MAG + "m/s.".
  } ELSE IF runstage:stage = 2 {
    PRINT "Executing node.".
    SET oldSAS TO SAS.
    SET oldRCS TO RCS.
    SET SAS TO FALSE.
    SET RCS TO TRUE.
    mnv:node:do(90, FALSE, 0).
    SET SAS TO oldSAS.
    SET RCS TO oldRCS.
  }
  syslog:upload().
  runstage:bump().
  runstage:preserve().
}
syslog:shutdown().

