////
// Library for launching rockets, as opposed to STS/Spaceplane.
// The Default Ascent profile is contained with this libs lexicon.
// Notice how the launch profile starts with 0.
////

boot:require("launch/profile").

GLOBAL launch_rocket IS LEXICON(
  "go", launch_rocket_go@,
  "default_profile", LIST(
//      (altitude, heading, throttle percent)
    LIST(0,     HEADING(90, 90), 1),
    LIST(1000,  HEADING(90, 85), 1),
    LIST(2000,  HEADING(90, 80), 1),
    LIST(4000,  HEADING(90, 75), 1), 
    LIST(5000,  HEADING(90, 65), 1),
    LIST(7000,  HEADING(90, 55), 1),
    LIST(10000, HEADING(90, 45), 1),
    LIST(15000, HEADING(90, 30), 1),
    LIST(25000, HEADING(90, 20), 1),
    LIST(30000, HEADING(90, 10), 1),
    LIST(35000, HEADING(90,  0), 1),
    LIST(35000, HEADING(90,  0), 1),
    LIST(50000, HEADING(90, -5), 1)
  )
).

////
// Implement a launch following an ascent profile.
////
FUNCTION launch_rocket_go {
    PARAMETER profile IS launch_rocket:default_profile.
    PARAMETER targetAltitude IS 100000.
    PARAMETER autoStage IS TRUE.
    PARAMETER endStage IS 0.
    PARAMETER countdown IS 5.
    PARAMETER autoStageAlgorithm IS staging:algorithm:flameOut@.
    PARAMETER noSafeStage IS LIST().
    PARAMETER profileOffset IS launch:profile:offsetNull@.
    PARAMETER shortStop IS 6000.

    LOCAL ascentSteps IS QUEUE().
    LOCAL pctComplete IS 0.
    LOCAL holdPid IS FALSE.
    LOCAL sasState IS SAS.
    SET SAS TO FALSE.

    FOR item IN profile {
      ascentSteps:PUSH(item).
    }

    launch:profile:load(ascentSteps, profileOffset).

    launch:profile:start().
    WAIT countdown.

    IF autoStage {
      staging:auto(endStage, autoStageAlgorithm@, TRUE, noSafeStage).
    }

    // Wait until we are withing some value of our target apoapsis, and let the launch profile do it's thing.
    WAIT UNTIL SHIP:APOAPSIS > targetAltitude - shortStop.
    // If we are here and there are more ascent profile stages, cancel them.
    if launch:profile:active {
      launch:profile:stop().
    }
    WAIT UNTIL NOT launch:profile:active.
    LOCK THROTTLE TO 0.

    // Now we've achieved target apoapsis, hold it until the atomosphere is cleared, and we are on point.
    LOCK STEERING TO PROGRADE.
    SET holdPid TO PIDLOOP(0.01, 0.005, 0.01, 0, 1).
    SET holdPid:SETPOINT TO targetAltitude.
    UNTIL ROUND(SHIP:Q, 4) < 0.0001 AND SHIP:ORBIT:APOAPSIS >= targetAltitude  { 
      LOCK THROTTLE TO holdPid:UPDATE(TIME:SECONDS, SHIP:APOAPSIS).
    }

    // Get rid of everything we don't want to bring to orbit with us.
    if autoStage {
      staging:stop().
      WAIT UNTIL STAGE:READY.
      UNTIL STAGE:NUMBER <= endStage {
        STAGE.
        WAIT UNTIL STAGE:READY.
      }
    }
    UNLOCK THROTTLE.
    UNLOCK STEERING.
    SET SAS TO sasState.

}
