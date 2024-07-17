////
// A library for orbital rv.
////

boot:require("math").
boot:require("syslog").
boot:require("std").

GLOBAL mnv_rendesvouz IS LEXICON(
    "timeToLan",                  mnv_rendesvouz_time_to_lan@,
    "coplanarPhaseAngle",         mnv_rendesvouz_coplanar_phase_angle@,
    "targetedHillClimb",          mnv_rendesvouz_targeted_hill_climb@,
    "distanceBetweenAt",          mnv_rendesvouz_distance_between_at@,
    "launchWindow",               mnv_rendesvouz_launch_window@,
    "targetedHillClimbReference", mnv_rendesvouz_targeted_hill_climb_reference@,
    "nodeWalkIn",                 mnv_rendesvouz_node_walk_in@,
    "nodeWalkInAtResolution",     mnv_rendesvouz_node_walk_in_at_resolution@,
    "cancelVelocity",             mnv_rendesvouz_cancel_velocity@,
    "cancelVelocityNoNode",       mnv_rendesvouz_cancel_velocity_no_node@
).

////
// Cancel out velocity between two bodies in orbit by aligning _chaser retrograde to the target and
// firing the engines.  This function is designed to match speed/orbits on initial approach to a 
// rendesvouz.  If you are looking for a more subtle station keeping manuever, see mnv_rendesvouz_station_keep.
// This is a blocking function.
// @PARAM _ca_t          - The approximate UT time of the cloest approach.
// @PARAM _target        - The target vessel. (Default: TARGET)
// @PARAM _chaser        - The chaser vessel. (Default: SHIP)
// @PARAM _safety_margin - The margin, in meters to add to the final distance when velocities cancel out. (Default: 200)
// @PARAM _initial_span  - See mnv_rendesvouz_targeted_hill_climb_reference()#_initial_span.
//                         (Default: see mnv_rendesvouz_targeted_hill_climb_reference().)
////
FUNCTION mnv_rendesvouz_cancel_velocity {
  PARAMETER _ca_t.
  PARAMETER _target IS TARGET.
  PARAMETER _chaser IS SHIP.
  PARAMETER _body IS _chaser:BODY.
  PARAMETER _safety_margin IS 200.
  PARAMETER _initial_span IS mnv_rendesvouz_targeted_hill_climb_reference(_target:ORBIT).

  LOCAL ca IS mnv_rendesvouz_targeted_hill_climb(_ca_t, _target, _chaser, _initial_span).
  LOCAL chaser_velocity IS VELOCITYAT(_chaser, ca["time"]):ORBIT.
  LOCAL target_retrograde IS VELOCITYAT(_target, ca["time"]):ORBIT - chaser_velocity.
  LOCAL delta_v IS target_retrograde:MAG.
  LOCAL fuel_mass IS telemetry:tsiolkovsky:fuelMass(delta_v).
  LOCAL end_mass IS _chaser:MASS - fuel_mass.
  LOCAL avg_accel IS (ABS(telemetry:performance:accelAtMass(end_mass) - telemetry:performance:availableAccel())) / 2.
  LOCAL burn_time IS ROUND(delta_v / avg_accel, 4).
  LOCAL safety_time IS _safety_margin / (target_retrograde:MAG / 2).
  LOCAL node_time IS TIMESTAMP(ca["time"]:SECONDS - safety_time).

  LOCAL future_position IS POSITIONAT(_chaser, ca["time"]) - _body:POSITION.

  LOCAL v_prograde IS chaser_velocity:NORMALIZED.
  LOCAL v_radial IS future_position:NORMALIZED.
  LOCAL v_normal IS VCRS(v_radial, v_prograde):NORMALIZED.
  LOCAL c_prograde IS target_retrograde * v_prograde.
  LOCAL c_radial IS target_retrograde * v_radial.
  LOCAL c_normal IS target_retrograde * v_normal.
  LOCAL nd_cancel IS NODE(node_time, c_radial, c_normal, c_prograde).
  syslog:msg(
    "Configuring node with (tm: " + node_time:FULL + ", rad: " + c_radial + ", nml: " + c_normal + ", pgd: " + c_prograde + ").",
    syslog:level:debug,
    "mnv:rendesvouz:cancelVelocity"
  ).
  RETURN nd_cancel.
}

////
// Cancel out velocity because a craft and a target without using a manuever node.  Nodes have a problem with this because
// as velocity changes, so does the target's prograde vector.  This is a blocking function.  It will not return until velocity
// is canceled, halting the main execute thread.
// @PARAM _ca_t          - The approximate time of the closest approach.
// @PARAM _target        - The target to rendesvouz with. (Default: TARGET).
// @PARAM _chaser        - The ship performing the manuever. (Default: SHIP).
// @PARAM _body          - The body to plan the manuever around. (Default: _chaser:BODY).
// @PARAM _safety_margin - The distance to add to the burn calculation so you don't stop too close to the target. (Default: 200m).
// @PARAM _warp_safety   - Time to add to subtract from the WARPTO call.  (Default: 2 minutes)
// @PARAM _initial_span  - See mnv_rendesvouz_targeted_hill_climb_reference (Default: mnv_rendesvouz_targeted_hill_climb_reference(_target:ORBIT)).
////
FUNCTION mnv_rendesvouz_cancel_velocity_no_node {
  PARAMETER _ca_t.
  PARAMETER _target IS TARGET.
  PARAMETER _chaser IS SHIP.
  PARAMETER _body IS _chaser:BODY.
  PARAMETER _safety_margin IS 200.
  PARAMETER _warp_safety IS TIMESPAN(0, 0, 0, 0, 30).
  PARAMETER _initial_span IS mnv_rendesvouz_targeted_hill_climb_reference(_target:ORBIT).

  LOCAL ca IS mnv_rendesvouz_targeted_hill_climb(_ca_t, _target, _chaser, _initial_span).
  LOCAL chaser_velocity IS VELOCITYAT(_chaser, ca["time"]):ORBIT.
  LOCAL target_velocity IS VELOCITYAT(_target, ca["time"]):ORBIT.
  LOCAL relative_velocity IS target_velocity - chaser_velocity.
  LOCAL relative_delta_v IS relative_velocity:MAG.
  LOCAL fuel_mass IS telemetry:tsiolkovsky:fuelMass(relative_delta_v).
  LOCAL end_mass IS _chaser:MASS - fuel_mass.
  LOCAL avg_accel IS (telemetry:performance:accelAtMass(end_mass) + telemetry:performance:availableAccel()) / 2.
  LOCAL burn_time IS ROUND(relative_delta_v / avg_accel, 4).
  LOCAL distance_covered IS burn_time * (relative_delta_v / 2) + _safety_margin.  // Start the burn as soon as target is this far away.
  LOCAL warp_to IS ca["time"]:SECONDS - burn_time - _warp_safety:SECONDS.
  LOCAL in_burn IS 0.
  syslog:msg(
    "During " + burn_time + "s burn, the target will cover " + distance_covered + "m (including safety margin), starting from a relative velocity of " + relative_delta_v + ".",
    syslog:level:debug,
    "mnv:rendesvouz:cancelVelocityNoNode"
  ).
  KUNIVERSE:TIMEWARP:WARPTO(warp_to).
  WAIT UNTIL KUNIVERSE:TIMEWARP:ISSETTLED AND KUNIVERSE:TIMEWARP:RATE = KUNIVERSE:TIMEWARP:RATELIST[0].
  WHEN _target:DISTANCE <= 100 THEN {
    // Lock steering to something static.
    LOCAL static IS (_target:ORBIT:VELOCITY:ORBIT - _chaser:ORBIT:VELOCITY:ORBIT):NORMALIZED:DIRECTION.
    LOCK STEERING TO static.
    RETURN FALSE.
  }
  WHEN _target:DISTANCE <= distance_covered THEN {
    LOCK THROTTLE TO 1.
    SET in_burn TO TIME:SECONDS.
    RETURN FALSE.
  }
  LOCK STEERING TO (_target:ORBIT:VELOCITY:ORBIT - _chaser:ORBIT:VELOCITY:ORBIT):NORMALIZED:DIRECTION.
  WAIT UNTIL math:helper:close((_target:ORBIT:VELOCITY:ORBIT - _chaser:ORBIT:VELOCITY:ORBIT):MAG, 0, 0.5) OR (in_burn > 0 AND TIME:SECONDS >= (in_burn + burn_time)).
  LOCK THROTTLE TO 0.
  UNLOCK STEERING.
  UNLOCK THROTTLE.
}






// WARNING:  This function currently only works when launching into a coplanar orbit.  It will need to be
//           modified in the future to take inclined/polar orbits into account.
// WARNING:  This function only works when the target is in a steady elliptical orbit.  Planned manuevers
//           will not be taken into account.  Parabolic and hyperbolic orbits are not yet supported.
// Launch from the surface of the planet to an encounter with target.
// @PARAM _target        - The ship to encounter. (Default: TARGET)
// @PARAM _chaser        - The ship that will be launched from the ground. (Default: SHIP)
// @PARAM _body          - The body launched from. (Default: SHIP:BODY).
// @PARAM _accuracy      - Target must be +/- this many degrees of true anomaly in order for launch window to be valid.
// @PARAM _extra_time    - Any extra time to add to the launch window, or add a negative to subtract time. (Default: 0)
// @PARAM _max_rotations - Abort afer examining this many rotations. (Default: 14).
// @PARAM _offset        - Internal API - See mnv_rendesvouz_launch_window_offset. 
// @RETURN - A UT TimeStamp of the closest launch window found.  If a launch window wasn't found, return a timestamp that is
//           less than current TIME:SECONDS.
////
FUNCTION mnv_rendesvouz_launch_window {
  PARAMETER _target IS TARGET.
  PARAMETER _chaser IS SHIP.
  PARAMETER _body IS SHIP:BODY.
  PARAMETER _accuracy IS 8.
  PARAMETER _extra_time IS 0.
  PARAMETER _max_rotations IS 14.
  PARAMETER _offset IS 0.

  LOCAL add_rotations IS 1.
  LOCAL closest IS 199999.

  // First we get a candidate launch window by looking at the first time the LANs of our
  // two craft line up.
  LOCAL candidate IS mnv_rendesvouz_time_to_lan(_target:ORBIT:LAN, _chaser:ORBIT:LAN + _offset, _body).
  if candidate < 0 {
    syslog:msg("Candidate time is : " + candidate + " it should no tbe less than 0.", syslog:level:warn, "mnv:rendesvouz:timeWindow").
  }

  // Next we approximate how long the launched ship is going to take to assume the transfer orbit.
  LOCAL climb_time IS TIMESPAN(math:kepler:period(math:kepler:sma(_body:RADIUS + _target:ORBIT:APOAPSIS, _body:RADIUS)):SECONDS / 2 + _extra_time).


  // Next we get what the _target vessel's true anomaly when it is "climb_time" seconds away from apoapsis.
  LOCAL desired_target_ta IS math:kepler:trueAnomalyAt((TIME:SECONDS + _target:ORBIT:ETA:APOAPSIS) - climb_time, _target:ORBIT, 0.1).

  // Get the targets actual true anomaly at the candidate time.
  LOCAL target_ta IS math:helper:clampTo360(math:kepler:trueAnomalyAt(candidate:SECONDS, _target:orbit, 1)).

  IF syslog:logLevel >= syslog:level:debug {
    LOCAL msg_fmt IS "Starting conditions: candidate:${candidate}, climb_time:${climb_time}, desired_target_ta:${desired_target_ta}, target_ta:${target_ta}.".
    LOCAL msg_args IS LEXICON(
      "candidate", candidate:FULL, "climb_time", climb_time:FULL, "desired_target_ta", desired_target_ta, "target_ta", target_ta
    ).
    LOCAL msg IS std:string:sprintf(msg_fmt, msg_args).
    syslog:msg(msg, syslog:level:debug, "mnv:rendesvouz:timeWindow").
  }

  // Next we are going to check the target's true anomaly every orbit, day by day, until we get a day and time that
  // the LAN and the True Anomaly are close_enough.
  UNTIL math:helper:close(desired_target_ta, target_ta, _accuracy) OR add_rotations >= _max_rotations  {
    SET candidate TO mnv_rendesvouz_time_to_lan(_target:ORBIT:LAN, _chaser:ORBIT:LAN + _offset, _body, add_rotations).
    SET target_ta TO math:helper:clampTo360(math:kepler:trueAnomalyAt(candidate:SECONDS, _target:ORBIT, 1)).
    LOCAL _c IS ABS(desired_target_ta - target_ta).
    IF syslog:logLevel >= syslog:level:debug {
      syslog:msg(
        "After adding " + add_rotations + " days, target's true anomaly will be " + target_ta + ", desired anomaly is " + desired_target_ta + " a diff of " + _c + ".",
        syslog:level:debug,
        "mnv:rendesvouz:launchWindow"
      ).
      IF _c < closest {
        SET closest TO _c.
      }
    }
    SET add_rotations TO add_rotations + 1.
  }

  IF add_rotations >= _max_rotations {
    IF syslog:logLevel >= syslog:level:debug {
      syslog:msg(
        "After " + add_rotations + " rotations, the closest the window got was " + closest + " degrees.",
        syslog:level:debug,
        "mnv:rendesvouz:timeWindow"
      ).
    }
    RETURN TIMESTAMP(TIME:SECONDS - 3600).
  }


  IF syslog:logLevel >= syslog:level:info {
    LOCAL window_time IS TIMESPAN(candidate:SECONDS - TIME:SECONDS).
    syslog:msg(
      "Found launch window at " + window_time:FULL + ".",
      syslog:level:info,
      "mnv:rendesvouz:timeWindow"
    ).
  }
  RETURN candidate.
}
////
// Calculate a launch window time that would set the launched vehicle's orbit to a specific LAN.
// @PARAM _target_lan      - The desired LAN of the orbit after launch.
// @PARAM _source_lan      - The current LAN of the orbit. (Default:  SHIP:ORBIT:LAN).
// @PARAM _body            - The body to calculate for. (Default: SHIP:BODY).
// @PARAM _add_rotation    - Add this many rotations of the body.
// @RETURN - A TIMESTAMP depicting the next avialable launch time.
////
FUNCTION mnv_rendesvouz_time_to_lan {
  PARAMETER _target_lan.
  PARAMETER _source_lan IS SHIP:ORBIT:LAN.
  PARAMETER _body IS SHIP:BODY.
  PARAMETER _add_rotation IS 0.

  LOCAL _t IS TIME:SECONDS + _body:ROTATIONPERIOD * _add_rotation.
  LOCAL _ang_diff IS math:helper:clampTo360(_target_lan - _source_lan).
  IF _ang_diff < 0 {
    syslog:msg("Difference is " + _target_lan + " - " + _source_lan + " = " + _ang_diff + "wrapped to 360 it should never be < 0.", syslog:level:warn, "mnv:rendesvouz:timetoLan").
  }

  LOCAL _diff IS _ang_diff / (_body:ANGULARVEL:MAG * CONSTANT:RADTODEG).
  IF _diff < 0 {
    syslog:msg("Difference is " + _diff + " it should never be < 0.", syslog:level:warn, "mnv:rendesvouz:timetoLan").
  }
  RETURN TIMESTAMP(_t + _diff). 
}

////
// Calculate the current phase angle between two objects.  This really only works when orbits
// are coplanar (or close enough).
// @PARAM _chaser - The ship that will be moving to rendesvouz with the target.
// @PARAM _target - The ship that the chaser will move to.
// @RETURN - The phase angle in degrees toward prograde.
////
FUNCTION mnv_rendesvouz_coplanar_phase_angle {
  PARAMETER _chaser IS SHIP:ORBIT.
  PARAMETER _target IS TARGET:ORBIT.

  LOCAL c_obt IS _chaser.
  LOCAL t_obt IS _target.

  IF c_obt:BODY <> t_obt:BODY {
    SET c_obt TO c_obt:BODY:ORBIT.
    SET t_obt TO t_obt:BODY:ORBIT.
  }

  // We just need the current true anomalies.
  LOCAL c_ta_rad IS c_obt:TRUEANOMALY * CONSTANT:DEGTORAD.
  LOCAL t_ta_rad IS t_obt:TRUEANOMALY * CONSTANT:DEGTORAD.

  // Normalize the true anomalies to [0, 2*pi)
  LOCAL two_pi TO 2 * CONSTANT:PI.
  LOCAL c_ta_rad_norm TO MOD(c_ta_rad, two_pi).
  LOCAL t_ta_rad_norm TO MOD(t_ta_rad, two_pi).

  // Adjust the true anomalies for difference in argument of periapsis.
  // Normalize the result.
  LOCAL c_omega_rad IS MOD(c_obt:ARGUMENTOFPERIAPSIS * CONSTANT:DEGTORAD, two_pi).
  LOCAL t_omega_rad IS MOD(t_obt:ARGUMENTOFPERIAPSIS * CONSTANT:DEGTORAD, two_pi).
  LOCAL c_ta_rad_adj IS MOD(c_ta_rad_norm + c_omega_rad, two_pi).
  LOCAL t_ta_rad_adj IS MOD(t_ta_rad_norm + t_omega_rad, two_pi).

  LOCAL phase_angle_rad IS MOD(t_ta_rad_adj - c_ta_rad_adj, two_pi).
  IF phase_angle_rad < 0 { SET phase_angle_rad TO phase_angle_rad + two_pi. }
  RETURN phase_angle_rad * CONSTANT:RADTODEG.
}

////
// Start at a specified time in the future, and find the closest approach to the target with a time
// boundary.  Bigger orbits get bigger time boundaries.  This is an expensive function.
// If the vessel has any planned manuevers, assume they were executed perfectly.
// elliptial orbits only.
// @PARAM _time         - The time that will serve as the center of the time boundary. Can be a TIMESPAN, TIMESTAMP or 
//                        scalar representing a UT time.
// @PARAM _target       - The vessel you are trying to approach.
// @PARAM _chaser       - The ship who's orbit is to be examined.
// @PARAM _initial_span - How far forward or back in time, expressed as a timespan to look for a closer
//                        approach.  (Default: See mnv_rendesvouz_hill_climb_reference)
// @RETURN - A Lexicon containing the keys "time" and "distance" which corresponde to the closest
//           approach elements.  The key "time" will be a UT TimeStamp, while the key "distance" will
//           be in meters.
////
FUNCTION mnv_rendesvouz_targeted_hill_climb {
  PARAMETER _time.
  PARAMETER _target.
  PARAMETER _chaser.
  PARAMETER _initial_span IS mnv_rendesvouz_targeted_hill_climb_reference(_target:ORBIT).

  LOCAL _return IS LEXICON("time", -1, "distance", -1).

  IF NOT _time:ISTYPE("Scalar"){
    IF _time:ISTYPE("TimeStamp"){ 
      SET _time TO _time:SECONDS.
    } ELSE IF _time:ISTYPE("TimeSpan") {
      SET _time TO TIME:SECONDS + _time:SECONDS.
    } ELSE {
      SET _return["error"] TO True.
      SET _return["message"] TO "Time values must be Scalar, TimeStamp or TimeSpan.".
      RETURN _return.
    }
  }

  IF NOT _initial_span:ISTYPE("Scalar") {
    IF _initial_span:ISTYPE("TimeSpan") {
      SET _initial_span TO _initial_span:SECONDS.
    } ELSE {
      SET _return["error"] TO True.
      SET _return["message"] TO "The iniital span must be of type Scalar or TimeSpan".
      RETURN _return.
    }
  }

  IF NOT _target:ISTYPE("Vessel") {
    SET _return["error"] TO True.
    SET _return["message"] TO "The target must be of type Vessel.".
    RETURN _return.
  }

  IF NOT _chaser:ISTYPE("Vessel") {
    SET _return["error"] TO True.
    SET _return["message"] TO "The chaser must be of type Vessel.".
    RETURN _return.
  }

  LOCAL _resolution IS - 1.
  LOCAL ca_time IS _time.
  LOCAL distance IS 999999999999999.
  LOCAL _level IS 0.

  UNTIL _resolution = 1 OR _level >= 9 {
    LOCAL start_time IS ca_time - _initial_span.
    LOCAL end_time IS ca_time + _initial_span.
    SET _resolution TO MAX(_initial_span / 10, 1).
    SET _initial_span TO _resolution.
    UNTIL start_time > end_time {
      LOCAL new_distance IS mnv_rendesvouz_distance_between_at(_target, _chaser, start_time). 
      IF new_distance < distance {
        SET ca_time TO start_time.
        SET distance TO new_distance.
      }
      SET start_time TO start_time + _resolution.
    }
    SET _level TO _level + 1.
  }
  SET _return["time"] TO TIMESTAMP(ca_time).
  SET _return["distance"] TO distance.
  RETURN _return.
}

////
// Algorithm for determining distance between vessel and target.
// @PARAM _target - The target ship.
// @PARAM _chaser - The origin ship.
// @RETURN - The distance between two objects at the given time.
////
FUNCTION mnv_rendesvouz_distance_between_at {
  PARAMETER _target.
  PARAMETER _chaser IS SHIP.
  PARAMETER _time IS TIME:SECONDS.

  // We aren't going to check param types here because speed is of the essence, however
  // the input should be checked before this function is called.

  RETURN (POSITIONAT(_chaser, _time) - POSITIONAT(_target, _time)):MAG.
}

////
// Walk a node in to the closest enocunter possible.
// @PARAM _node - The node to adjust.
// @PARAM _encounter_eta - The ETA of the closest approach.
// @PARAM _target - The target of the encounter. (Default: TARGET)
// @PARAM _chaser - The ship moving to intercept _target (Default: SHIP)
// @PARAM _resolutions - A list of resolutions adjust the burn by (Default; LIST(10, 1, 0.5)).
// @PARAM _max_iterations - The maximum number of iterations to expend on any loop. (Default; 100)
// @RETURN A Lexicon of "time" and "distance" of the walked in closest appraoch.
////
FUNCTION mnv_rendesvouz_node_walk_in {
  PARAMETER _node.
  PARAMETER _encounter_eta.
  PARAMETER _target IS TARGET.
  PARAMETER _chaser IS SHIP.
  PARAMETER _resolutions IS LIST(10, 5, 1, 0.5, 0.1, 0.05).
  PARAMETER _max_iterations IS 100.

  LOCAL separation IS LEXICON("distance", -1, "time", -1).

  FOR _res IN _resolutions {
      SET separation TO mnv_rendesvouz_node_walk_in_at_resolution(_node, _encounter_eta, _res, _target, _chaser, _max_iterations).
  }
  return separation.
}

////
// Walk a node in to the closest enocunter possible.
// @PARAM _node - The node to adjust.
// @PARAM _encounter_eta - The ETA of the closest approach.
// @PARAM _target - The target of the encounter. (Default: TARGET)
// @PARAM _chaser - The ship moving to intercept _target (Default: SHIP)
// @PARAM _resolution - The resolution to adjust the burn by each resolution (Default; LIST(10, 1, 0.5)).
// @PARAM _max_iterations - The maximum number of iterations to expend on any loop. (Default; 100)
// @RETURN A Lexicon of "time" and "distance" of the walked in closest appraoch.
////
FUNCTION mnv_rendesvouz_node_walk_in_at_resolution {
  PARAMETER _node.
  PARAMETER _encounter_eta.
  PARAMETER _resolution.
  PARAMETER _target IS TARGET.
  PARAMETER _chaser IS SHIP.
  PARAMETER _max_iterations IS 100.

  // Some sanity checking.
  LOCAL added IS FALSE.
  FOR setNode IN ALLNODES {
    IF setNode:TIME = _node:TIME {
      SET added TO TRUE.
    }
  }
  IF NOT added{
    ADD _node. // Node must be added to the flight plan before it can be walked in.
  }


  LOCAL improved IS TRUE.
  LOCAL pgd_improved IS TRUE.
  LOCAL nml_improved IS TRUE.
  LOCAL rad_improved IS TRUE.
  LOCAL unimproved_count IS 0.
  LOCAL iter IS 1.

  LOCAL node_pgd IS _node:PROGRADE.
  LOCAL node_nml IS _node:NORMAL.
  LOCAL node_rad IS _node:RADIALOUT.

  LOCAL sep IS mnv_rendesvouz_targeted_hill_climb(_encounter_eta, _target, _chaser).
  LOCAL old_sep IS sep.

  FUNCTION update_sep {
    SET sep TO mnv_rendesvouz_targeted_hill_climb(old_sep["time"], _target, _chaser).
  }

  UNTIL NOT improved OR iter >= _max_iterations {
    UNTIL NOT rad_improved {
      LOCAL _og IS _node:RADIALOUT.
      SET _node:RADIALOUT TO _node:RADIALOUT + _resolution.
      update_sep().
      IF sep["distance"] >= old_sep["distance"] { 
        SET _node:RADIALOUT TO _og.
        SET _resolution TO _resolution * -1.
        SET _node:RADIALOUT TO _node:RADIALOUT + _resolution.
        update_sep().
        IF sep["distance"] >= old_sep["distance"] {
          SET _node:RADIALOUT TO _og.
          SET rad_improved TO FALSE.
          SET sep TO old_sep.
          syslog:msg(
            "Altered node radialout by " + (node_rad - _node:RADIALOUT) + "m/s.",
            syslog:level:debug,
            "mnv:rendesvouz:nodeWalkInAtResolution"
          ).
        }
      }
      IF rad_improved {
        SET old_sep TO sep.
        SET pgd_improved TO TRUE.
        SET nml_improved TO TRUE.
      }
    }

    UNTIL NOT nml_improved {
      LOCAL _og IS _node:NORMAL.
      SET _node:NORMAL TO _node:NORMAL + _resolution.
      update_sep().
      IF sep["distance"] >= old_sep["distance"] {
        SET _node:NORMAL TO _og.
        SET _resolution TO _resolution * -1.
        SET _node:NORMAL TO _node:NORMAL + _resolution.
        update_sep().
        IF sep["distance"] >= old_sep["distance"] {
          SET _node:NORMAL TO _og.
          SET nml_improved TO FALSE.
          SET sep TO old_sep.
          syslog:msg(
            "Altered node normal by " + (node_nml - _node:NORMAL) + "m/s.",
            syslog:level:debug,
            "mnv:rendesvouz:nodeWalkInAtResolution"
          ).
        } 
      }
      IF nml_improved {
        SET old_sep TO sep.
        SET pgd_improved TO TRUE.
        SET rad_improved TO TRUE.
      }
    }

    UNTIL NOT pgd_improved {
      LOCAL _og IS _node:PROGRADE.
      SET _node:PROGRADE TO _node:PROGRADE + _resolution.
      update_sep().
      IF sep["distance"] >= old_sep["distance"] {
        SET _node:PROGRADE TO _og.
        SET _resolution TO _resolution * -1.
        SET _node:PROGRADE TO _node:PROGRADE - _resolution.
        update_sep().
        IF sep["distance"] >= old_sep["distance"] {
          SET _node:PROGRADE TO _og.
          SET pgd_improved TO FALSE.
          SET sep TO old_sep.
          syslog:msg(
            "Altered node prograde by " + (node_pgd - _node:PROGRADE) + "m/s.",
            syslog:level:debug,
            "mnv:rendesvouz:nodeWalkInAtResolution"
          ).
        } 
      }
      IF pgd_improved {
        SET old_sep TO sep.
        SET rad_improved TO TRUE.
        SET nml_improved TO TRUE.
      }
    }
    // Set exit conditions.
    SET iter TO iter + 1.
    IF NOT pgd_improved AND NOT nml_improved AND NOT rad_improved {
      IF unimproved_count >= 3 { 
        SET improved TO FALSE.
      } ELSE {
        SET unimproved_count TO unimproved_count + 1.
      }
    } ELSE {
      SET unimproved_count TO 0.
    }
  }
  IF iter > 99 { 
    syslog:msg(
      "Max iterations reached.  Node will not be as accurate as it could be.",
      syslog:level:error,
      "mnv:rendesvouz:nodeWalkInAtResolution"
    ).
  }
  return sep.
}

////
// Generate a reference value for closest approach hill climb.  The bigger the orbit, the bigger the time
// window that should be scanned.
// @PARAM _obt - The orbit to examine. (Default: SHIP:ORBIT).
// @RETURN - A time window to scan.
////
FUNCTION mnv_rendesvouz_targeted_hill_climb_reference {
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL _reference_sma IS 100000.
  LOCAL _reference_window IS 300.  // 5 minutes (+/- 2.5 minutes)
  LOCAL _factor IS _obt:SEMIMAJORAXIS / _reference_sma.

  RETURN _reference_window * _factor.
}
