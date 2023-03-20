////
// Library for handling launch profiles.
////
boot:require("telemetry").

GLOBAL launch_profile IS LEXICON(
  "ACTIVE", FALSE,
  "SHUTDOWN", FALSE,
  "load", launch_profile_load@,
  "start", launch_profile_start@,
  "stop", launch_profile_stop@,
  "offsetTVector", launch_profile_offset_tvector@,
  "offsetNull", launch_profile_offset_null@
).

////
// Load the next element of a launch profile.
////
FUNCTION launch_profile_load {
  PARAMETER steps.
  PARAMETER offsetFunction IS launch_profile_offset_null@.

  LOCAL this IS steps:POP().

  syslog:msg("Setting watcher for launch profile altitude " + this[0] + "m, current altitude is " + SHIP:ALTITUDE + "m.", syslog:level:info, "launch:profile:load").
  WHEN (SHIP:ALTITUDE >= this[0] AND launch_profile["ACTIVE"]) OR launch_profile["SHUTDOWN"] THEN {
    IF launch_profile["SHUTDOWN"] {
      syslog:msg("End launch profile activity.  Shutting down").
      LOCK THROTTLE TO 0.
      UNLOCK THROTTLE.
      SET launch_profile["ACTIVE"] TO FALSE.
      SET launch_profile["SHUTDOWN"] TO FALSE.
      RETURN FALSE.
    }
    LOCAL this_exp IS LEXICON(
      "alt", this[0],
      "dir", this[1],
      "tp", this[2]
    ).
    LOCAL msg IS std:string:sprintf("Executing profile step (${alt}, ${dir}, ${tp}).", this_exp).
    syslog:msg(msg, syslog:level:info, "launch:profile:load").
    LOCAL finalDirection IS offsetFunction(this[1]).
    LOCK STEERING TO finalDirection.
    LOCK THROTTLE TO this[2].
    if steps:LENGTH > 0 {
      launch_profile_load(steps).
    } else {
      SET launch_profile["ACTIVE"] TO FALSE.
    }
    RETURN FALSE.
  }
}

////
// Start launch profile watching.
////
FUNCTION launch_profile_start {
  syslog:msg("Starting launch profile.", syslog:level:info, "launch:profile:start").
  SET launch_profile["SHUTDOWN"] TO FALSE.
  SET launch_profile["ACTIVE"] TO TRUE.
}

////
// Stop launch profile watching.
////
FUNCTION launch_profile_stop {
  syslog:msg("Stopping launch profile.", syslog:level:info, "launch:profile:stop").
  SET launch_profile["SHUTDOWN"] TO TRUE.
  UNLOCK STEERING.
}

////
// Offset the pitch element of the profile's heading by the difference between
// the ship's facing vector and the thrust vector.  This is especially useful for
// shuttle type craft.
////
FUNCTION launch_profile_offset_tvector {
  PARAMETER hdg.

  LOCAL tVector IS telemetry:performance:thrustVector().
  LOCAL offset IS VANG(tVector, SHIP:FACING:FOREVECTOR).
  LOCAL offsetDir IS R(offset, 0, 0).
  RETURN R(hdg:PITCH + offsetDir:PITCH, hdg:YAW, hdg:ROLL).
}

////
// The null heading offset, it doesn't do anything. It is used as the default
// offset.
////
FUNCTION launch_profile_offset_null {
  PARAMETER hdg.

  RETURN hdg.
}
