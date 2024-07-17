boot:require("syslog").
boot:require("parts").

GLOBAL mnv_rcs IS LEXICON(
  "__shortcircuit",         FALSE,
  "fineApoapsis",           mnv_rcs_fine_apoapsis@,
  "finePeriapsis",          mnv_rcs_fine_periapsis@,
  "shortCircuit",           mnv_rcs_short_circuit@,
  "cancelVelocity",         mnv_rcs_cancel_velocity@,
  "relativeVelocity",       mnv_rcs_relative_velocity@,
  "relativeVelocityHold",   mnv_rcs_relative_velocity_hold@,
  "closeIn",                mnv_rcs_close_in@
).


////
// Short circuit an RCS control manuever.
////
FUNCTION mnv_rcs_short_circuit {
  SET mnv_rcs["__shortcircuit"] TO TRUE.
}


////
// Close an RCS capable distance with _target.
// @PARAM _chaser               - The ship doing the approaching. (Default: SHIP).
// @PARAM _target               - The ship to approach. (Default: TARGET).
// @PARAM _distance             - The distance from target to stop at. (Default: 25)
// @PARAM _max_attempt_distance - The maximum distance to attempt with RCS controls.  Longer distances probably require main engines. (Default: 2000)
// @PARAM _parts                - A list of all the rcs parts on the ship, or an empty list to tell this function to look them up.  (Default: LIST()).
// @PARAM _part_modules         - A list of rcs part modules, or an empty list to tell this function to look them up. (Default: LIST()).
// @PARAM _patterns             - RCS part name patterns. (Default: See parts:rcs:defaultPartPattern).
// @PARAM _module_names         - RCS part module name patterns. (Default: see parts:rcs:defaultModuleNames).
////
FUNCTION mnv_rcs_close_in {
  PARAMETER _chaser IS SHIP.
  PARAMETER _target IS TARGET.
  PARAMETER _distance IS 25.
  PARAMETER _max_attempt_distance IS 2000.
  PARAMETER _parts IS LIST().
  PARAMETER _part_modules IS LIST().
  PARAMETER _patterns IS parts:rcs:defaultPartPatterns.
  PARAMETER _module_names IS parts:rcs:defaultModuleNames.

  LOCAL done IS FALSE.

  UNTIL done {
    SET done TO _mnv_rcs_close_in(_chaser, _target, _distance, _max_attempt_distance, _parts, _part_modules, _patterns, _module_names).
  }
}

////
// Internal API.
////
FUNCTION _mnv_rcs_close_in {
  PARAMETER _chaser.
  PARAMETER _target.
  PARAMETER _distance.
  PARAMETER _max_attempt_distance.
  PARAMETER _parts.
  PARAMETER _part_modules.
  PARAMETER _patterns.
  PARAMETER _module_names.


  IF _target:DISTANCE > _max_attempt_distance {
    syslog:msg(
      "Refusing to attempt RCS close in operation with target more than " + _max_attempt_distance + " away.  Main engines should probably be used here.",
      syslog:level:warn,
      "mnv:rcs:closeIn"
    ).
    RETURN -1.
  }

  IF _target:DISTANCE < _distance {
    // TODO:  This is not how I want this function to work.  I need to implement logic so that
    //        if _target:DISTANCE < _distance, then SHIP moves away from target to appropriate
    //        distance.
    RETURN TRUE.
  }

  LOCAL rcs_parts IS _parts.
  LOCAL part_modules IS _part_modules.

  IF rcs_parts:EMPTY {
    SET rcs_parts TO parts:rcs:getRCSParts(_chaser, _patterns).
  }

  IF part_modules:EMPTY {
    SET part_modules TO parts:rcs:getRCSModules(rcs_parts, _module_names).
  }

  LOCAL travel_distance IS _target:DISTANCE - _distance.
  LOCAL reversed IS FALSE.   // We are facing toward target.
  LOCAL align_vector IS _target:DIRECTION:FOREVECTOR.
  LOCAL fore_thrust IS parts:rcs:getTraverseThrustFor("fore", _chaser, rcs_parts).
  LOCAL aft_thrust IS parts:rcs:getTraverseThrustFor("aft", _chaser, rcs_parts).
  // add additional 5% buffer

  IF VANG(align_vector, _chaser:FACING:FOREVECTOR) > 90 {
    SET align_vector TO -align_vector.
    SET reversed TO TRUE.     // We are facing away from target.
    LOCAL tmp IS aft_thrust.
    SET aft_thrust TO fore_thrust.
    SET fore_thrust TO tmp.
  }


  LOCAL close_speed IS mnv:getOptimalClosingSpeed(travel_distance * 0.95, fore_thrust, aft_thrust).
  LOCAL braking_distance IS (close_speed ^ 2) / (2 * aft_thrust).

  IF aft_thrust <= 0 {
    syslog:msg(
      "Aft thrust is " + aft_thrust + "kN , cannot stop.",
      syslog:level:error,
      "mnv:rcs:closeIn"
    ).
    RETURN 1.
  }.

  IF fore_thrust <= 0 {
    syslog:msg(
      "Fore thrust is " + fore_thrust + "kN , cannot stop.",
      syslog:level:error,
      "mnv:rcs:closeIn"
    ).
    RETURN 1.
  }.

  mnv_rcs_cancel_velocity(_chaser, _target, 0.025, part_modules).

  syslog:msg(
    "Ship " + _chaser:NAME + " is closing with " + _target:NAME + " at a closing speed of " + ROUND(close_speed, 2) + "m/s.",
    syslog:level:info,
    "mnv:rcs:closeIn"
  ).

  LOCK STEERING TO align_vector.
  FROM { LOCAL x IS 4. } UNTIL x = 0 STEP { SET x TO x - 1. } DO {
    WAIT UNTIL math:helper:close(VANG(_chaser:FACING:FOREVECTOR, align_vector), 0, 0.5).
  }

  mnv_rcs_relative_velocity_hold(part_modules, _chaser, _target, 0.05, ROUND(close_speed, 1), reversed).
  LOCAL loops IS 0.
  LOCAL old_distance IS _target:DISTANCE.
  UNTIL _target:DISTANCE <= _distance * 1.1 + braking_distance {
    SET loops TO loops + 1.
    IF _target:DISTANCE > old_distance { BREAK. } // We've gone past the target.
    SET old_distance TO _target:DISTANCE.
    LOCAL speed_limit IS mnv:getSpeedLimit(_target:DISTANCE).
    IF speed_limit < close_speed {
      mnv_rcs_relative_velocity_hold(part_modules, _chaser, _target, 0.05, ROUND(speed_limit, 1), reversed).
      SET braking_distance TO (speed_limit ^ 2) / (2 * aft_thrust).
      SET close_speed TO speed_limit.
    }
    IF MOD(loops, 5) = 0 {
      syslog:msg (
        "Waiting until target distance (" + _target:distance + ") <= braking distance (" + (_distance * 1.1 + braking_distance) + ").",
        syslog:level:debug,
        "mnv:rcs:closeIn"
      ).
    }
    WAIT 0.25.
  } 
  UNLOCK STEERING.

  mnv_rcs_cancel_velocity(_chaser, _target, 0.025, part_modules).
  IF _target:DISTANCE <= _distance * 1.1 {
    RETURN TRUE.
  }
  RETURN FALSE.
}


////
// Cancel the relative velocity between _chaser and _target.  This function assumes the craft has both
// forward and aft RCS control.
// @PARAM _chaser       - The craft who's relative velocity should be canceled. (Default: SHIP).
// @PARAM _target       - The craft who's velocity is to be matched. (Default: TARGET).
// @PARAM _close_enough - How close to 0 do we need to get in order to consider velocity canceled. (Default: 0.05).
// @PARAM _patterns     - The name regexp patterns to use to find RCS thurster parts. (Default See parts:rcs:defaultPartPatterns).
// @PARAM _module_names - The module names of the RCS control modules. (Default: See parts:rcs:defaultModuleNames).
////
FUNCTION mnv_rcs_cancel_velocity {
  PARAMETER _chaser IS SHIP.
  PARAMETER _target IS TARGET.
  PARAMETER _close_enough IS 0.025.
  PARAMETER _part_modules IS LIST().
  PARAMETER _patterns IS parts:rcs:defaultPartPatterns.
  PARAMETER _module_names IS parts:rcs:defaultModuleNames.

  // velocity, positive if closing, negative otherwise.
  LOCAL initial_velocity IS mnv_rcs_relative_velocity(_chaser, _target).
  IF math:helper:close(initial_velocity, 0, _close_enough) {
    RETURN.
  }

  // Setup all the part info.
  LOCAL part_modules IS LIST().
  IF _part_modules:EMPTY {
    LOCAL rcs_parts IS parts:rcs:getRCSParts(_chaser, _patterns).
    SET part_modules TO parts:rcs:getRCSModules(rcs_parts, _module_names).
  } ELSE {
    SET part_modules TO _part_modules.
  }
  
  // Target retrograde.
  LOCAL init_align_vector IS -((_chaser:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):NORMALIZED).
  // Direction craft is facing.
  LOCAL initial_facing IS _chaser:FACING:FOREVECTOR.
  // Do we need to reverse the RCS controls to burn in the right direction.  this is a combimation of
  // whether or not we are aligned prograde or retrograde and if we are closing or widening.
  LOCAL reversed IS FALSE.
  LOCAL align_vector_multiplier IS 1.
  IF VANG(initial_facing, init_align_vector) <= 90 {
    // _chaser will align to target retrograde.
    IF initial_velocity > 0 {
      // Initially are aligned target retrograde and closing with it.  We need to reverse the controls in order
      // to burn in the target retrograde direction when velocity is > 0 and burn target prograde when velocity < 0.
      SET reversed TO TRUE.
    }
  } ELSE {
    // We will align to target prograde.
    SET align_vector_multiplier TO -1.
    IF initial_velocity < 0 {
      // Initial we are aligned to target prograde and moving away from it.  We need to reverse the controls in ordre
      // to brun in the target retrograde direction when velocity is < 0 and burn target prograde when velocity is > 0.
      SET reversed TO TRUE.
    }
  }
  LOCAL LOCK steering_vector TO -((_chaser:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):NORMALIZED) * align_vector_multiplier.
  LOCK STEERING TO steering_vector.
  // We want to hold this for a 4 count, just to make sure we don't accidentally trip it when the vehicle's
  // facing direction whips past it.
  FROM { LOCAL x IS 4. } UNTIL x = 0 STEP { SET x TO x -1. } DO {
    WAIT UNTIL math:helper:close(VANG(_chaser:FACING:FOREVECTOR, steering_vector), 0, 0.5).
    WAIT 0.2.
  }
  mnv_rcs_relative_velocity_hold(part_modules, _chaser, _target, _close_enough, 0, reversed).
  UNLOCK STEERING.
}

////
// Hold a relative velocity between _chaser and _target.  This function assumes the craft has both
// forward and aft RCS control.  This function blocks until relative velocity is achieved.
// @PARAM _part_modules    - The RCS modules of the RCS parts to use for fore/aft control.
// @PARAM _chaser          - The craft who's relative velocity should be canceled. (Default: SHIP).
// @PARAM _target          - The craft who's velocity is to be matched. (Default: TARGET).
// @PARAM _close_enough    - How close to 0 do we need to get in order to consider velocity canceled. (Default: 0.05).
// @PARAM _target_velocity - The velocity to hold at. (Default: 0)
////
FUNCTION mnv_rcs_relative_velocity_hold {
  PARAMETER _part_modules.
  PARAMETER _chaser IS SHIP.
  PARAMETER _target IS TARGET.
  PARAMETER _close_enough IS 0.05.
  PARAMETER _target_velocity IS 0.
  PARAMETER _reverse_control IS FALSE.
  
  LOCAL og_tl_values IS parts:rcs:storeThrustLimiter(_part_modules).
  LOCAL og_rcs_value IS RCS.

  // P - controller for thruster power.  If we are +/- 10m/s or more thrusters should be at full power,
  // otherwise back off proportionally.  We want to utilize the abosolute value of the relative velocity
  // as input to this P-Controller.  It's output should never be negative.
  LOCAL rcs_thrust_PID IS PIDLOOP(10, 0, 0, -100, 100).

  // P - controller for thrust direction.  By +/- 10m/s, thruster control should be +/- 1.
  // A positive value means we need to accelerate, a negative that we must decelerate.
  LOCAL rcs_control_PID IS PIDLOOP(10, 0, 0, -1, 1).

  // the sepoint for each pid is the target velocity.
  SET rcs_thrust_PID:SETPOINT TO _target_velocity.
  SET rcs_control_PID:SETPOINT TO _target_velocity.

  SET mnv_rcs["__shortcircuit"] TO FALSE.
  SET RCS TO TRUE.
  LOCK THROTTLE TO 0.
  // main loop to work until relative velocity is _target_velocity.
  LOCAL LOCK relative_velocity TO mnv_rcs_relative_velocity(_chaser, _target).
  UNTIL math:helper:close(relative_velocity, _target_velocity, _close_enough) OR mnv_rcs["__shortcircuit"] {
    LOCAL thrust_value IS MAX(ABS(rcs_thrust_PID:UPDATE(TIME:SECONDS, relative_velocity)), 0.5).
    LOCAL control_value IS rcs_control_PID:UPDATE(TIME:SECONDS, relative_velocity).
    parts:rcs:setThrustLimiter(_part_modules, thrust_value).
    IF _reverse_control {
      SET control_value TO control_value * -1.
    }
    SET _chaser:CONTROL:FORE TO control_value.
    IF syslog:loglevel >= syslog:level:trace {
      LOCAL vars IS LEXICON(
        "relvel",     relative_velocity,
        "thrustval",  thrust_value,
        "controlval", control_value,
        "control",    "Control is standard."
      ).
      IF _reverse_control { 
        SET vars["control"] TO "Control is flipped.".
      }
      LOCAL fmt IS "Setting RCS thrusters to power level ${thrustval} and RCS control to position ${controlval} based on ".
      SET fmt TO fmt + " a relative velocity value of ${relvel}.  ${control}".
      LOCAL msg IS std:string:sprintf(fmt, vars).
      syslog:msg(msg, syslog:level:trace, "mnv:rcs:relativeVelocityHold").
    }
  }
  SET _chaser:CONTROL:FORE TO 0.
  SET RCS TO FALSE.
  UNLOCK THROTTLE.
  SET RCS TO og_rcs_value. 
  parts:rcs:restoreThrustLimiter(_part_modules, og_tl_values).
}

////
// Calculate the relative velocity betwene two crafts, expressed as a positive or negative scalar depending
// on whether or not the relative motion is bringing the craft together or further apart.
// @PARAM _chaser - The "moving" ship in this relationship. (Default: SHIP)
// @PARAM _target - The static or frame of reference ship in this relationship. (Default: TARGET).
// @RETURN - The relative velocity, either postive or negative between the two craft. If the craft
//           are closing, the number is postive, if they are separating the value is negative.
////
FUNCTION mnv_rcs_relative_velocity {
  PARAMETER _chaser IS SHIP.
  PARAMETER _target IS TARGET.

  LOCAL __relative_velocity IS _chaser:VELOCITY:ORBIT - _target:VELOCITY:ORBIT.
  LOCAL __relative_position IS _chaser:POSITION - _target:POSITION.
  LOCAL __dot_product IS __relative_position * __relative_velocity.
  LOCAL mag IS __relative_velocity:MAG.

  IF __dot_product < 0 {
    RETURN mag.
  }
  RETURN -mag.
}

////
// Fine tune an apoapsis  altitude.  This will only work if RCS is equipped on the 
// spacecraft.
// @PARAM t_altitude    - The target altitude for the apoapsis.
// @PARAM rcs_thrusters - List of parts that will participate in the fine control.
// @PARAM _ob           - The orbit to work with. (Default: SHIP:ORBIT).
// @PARAM error_margin  - The margin for error.  (Default: 0.5 meters).
// @PARAM module_names  - A list of partmodule names that accept the "thrust limiter" field.
//                        (Default: LIST("ModuleRCSFX"))
////
FUNCTION mnv_rcs_fine_apoapsis {
  PARAMETER t_altitude.
  PARAMETER rcs_thrusters.
  PARAMETER _obt IS SHIP:ORBIT.
  PARAMETER error_margin IS 0.5.
  PARAMETER module_names IS LIST("ModuleRCSFX").

  __mnv_rcs_fine(t_altitude, rcs_thrusters, error_margin, module_names, _obt, 1).
}

////
// Fine tune an periapsis  altitude.  This will only work if RCS is equipped on the 
// spacecraft.
// @PARAM t_altitude    - The target altitude for the apoapsis.
// @PARAM rcs_thrusters - List of parts that will participate in the fine control.
// @PARAM _obt           - The orbit to work with. (Default: SHIP:ORBIT).
// @PARAM error_margin  - The margin for error.  (Default: 0.5 meters).
// @PARAM module_names  - A list of partmodule names that accept the "thrust limiter" field.
//                        (Default: LIST("ModuleRCSFX"))
////
FUNCTION mnv_rcs_fine_periapsis {
  PARAMETER t_altitude.
  PARAMETER rcs_thrusters.
  PARAMETER _obt IS SHIP:ORBIT.
  PARAMETER error_margin IS 0.5.
  PARAMETER module_names IS LIST("ModuleRCSFX").

  __mnv_rcs_fine(t_altitude, rcs_thrusters, error_margin, module_names, _obt, -1).
}

////
// API Internal.
////
FUNCTION __mnv_rcs_fine {
  PARAMETER t_altitude.
  PARAMETER rcs_thrusters.
  PARAMETER error_margin.
  PARAMETER module_names.
  PARAMETER _obt.
  PARAMETER operation.

  IF operation < 0 {
    LOCK check_point TO _obt:PERIAPSIS.
  } ELSE {
    LOCK check_point TO  _obt:APOAPSIS.
  }

  SET mnv_rcs["__shortcircuit"] TO FALSE.

  LOCAL _modules IS LIST().
  LOCAL _init_values IS LIST().
  LOCAL thrust_value IS 0.
  LOCAL _init_rcs_value IS RCS.
  syslog:msg("Storing initial RCS activation value as " + _init_rcs_value + ".", syslog:level:debug, "mnv:rcs:fineApoapsis").
  LOCK _error_d TO check_point - t_altitude.
  LOCK _error_i TO ABS(_error_d) * -1.

  FOR rcs IN rcs_thrusters {
    FOR module_name IN module_names {
      IF rcs:HASMODULE(module_name) {
        SET _this_module TO rcs:GETMODULE(module_name).
        _modules:ADD(_this_module).
        _init_values:ADD(_this_module:GETFIELD("thrust limiter")).
        syslog:msg(
          "Storing RCS thrust limiter value " + _init_values[_init_values:LENGTH - 1] + " for part " + rcs:TITLE + ".",
          syslog:level:debug,
          "mnv:rcs:fineApoapsis"
        ).
      }
    }
  }

  LOCK STEERING TO PROGRADE.
  LOCK THROTTLE TO 0.
  SET RCS TO TRUE.
  SET rcs_thrust_PID TO PIDLOOP(0.01, 0, 0, 0.5, 100).
  SET rcs_thrust_PID:SETPOINT TO 0.
  SET rcs_control_PID TO PIDLOOP(0.1, 0, 0, -1, 1).
  SET rcs_control_PID:SETPOINT TO t_altitude.
  WAIT UNTIL math:helper:close(VANG(SHIP:PROGRADE:VECTOR, SHIP:FACING:VECTOR), 0, 0.2).
  UNTIL math:helper:close(check_point, t_altitude, error_margin) OR mnv_rcs["__shortcircuit"] {
    SET thrust_value TO rcs_thrust_pid:UPDATE(TIME:SECONDS, _error_i).
    FOR rcs_module IN _modules {
      rcs_module:SETFIELD("thrust limiter", thrust_value).
    }
    SET SHIP:CONTROL:FORE TO rcs_control_PID:UPDATE(TIME:SECONDS, check_point).
  }
  SET SHIP:CONTROL:FORE TO 0.
  SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
  syslog:msg("Restoring initial RCS activation value of " + _init_rcs_value + ".", syslog:level:debug, "mnv:rcs:fineApoapsis").
  WAIT 1.
  SET RCS TO _init_rcs_value.
  UNLOCK THROTTLE.
  UNLOCK STEERING.
  UNLOCK check_point.
  WAIT 1.
  SET RCS TO _init_rcs_value.
  FROM {LOCAL x IS 0.} UNTIL x = _modules:LENGTH STEP { SET x TO x + 1.} DO {
    syslog:msg(
      "Restoring RCS thrust limiter value of " + _init_values[x] + " to " + _modules[x]:PART:TITLE + ".", 
      syslog:level:debug,
      "mnv:rcs:fineApoapsis"
    ).
    _modules[x]:SETFIELD("thrust limiter", _init_values[x]).
  }
}
