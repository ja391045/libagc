////
// Library which calculates performance of the ship.
////

boot:require("syslog").
boot:require("telemetry/performance/atm").

GLOBAL telemetry_performance IS LEXICON(
//  "atm",             telemetry_performance_atm,
  "availableThrust", telemetry_performance_available_thrust@,
  "currentThrust",   telemetry_performance_current_thrust@,
  "availableAccel",  telemetry_performance_available_accel@,
  "currentAccel",    telemetry_performance_current_accel@,
  "accelAtMass",     telemetry_performance_accel_at_mass@,
  "radius",          telemetry_performance_radius@,
  "pull",            telemetry_performance_pull@,
  "avgEv",           telemetry_performance_avg_exhaust_velocity@,
  "thrustVector",    telemetry_performance_thrustvector@,
  "averageThrust",   telemetry_performance_average_thrust@
).

////
// Calculate the highest possible amount of thrust currently available. Engines which 
// are flamed out, deactivate, or not yet ignited show '0' for available thrust, so they
// need not be explicitly filtered out of the sum.
// @RETURN - Scalar - Available thrust in kN.
////
FUNCTION telemetry_performance_available_thrust {
  LOCAL kn IS 0.

  FOR engine IN SHIP:ENGINES {
    IF engine:IGNITION { 
      SET kn TO kn + engine:AVAILABLETHRUST.
    }
  }
  IF kn <= 0 {
    RETURN 1.
  }
  RETURN kn.
}

////
// Calculate the current amount of thrust produced by the ship at this very moment, taking
// throttle possition and all other factors into account.
// @RETURN - Scalar - Current thrust in kN.
////
FUNCTION telemetry_performance_current_thrust {
  LOCAL _eng IS 0.
  LOCAL kn IS 0.

  FOR engine IN SHIP:ENGINES { 
    IF engine:IGNITION {
      SET kn TO kn + engine:THRUST. 
    }
  }
  RETURN kn.
}

////
// Calculate the average thrust produced by each engine in a ship.  This is handy for spaceplanes
// with RAPIER engines to swap modes.
////
FUNCTION telemetry_performance_average_thrust {
  LOCAL totalThrust IS 0.
  LOCAL engineCount IS 0.

  //  A lot of this redudant with the current_thrust method, but I don't want to walk the parts list twice.
  FOR engine IN SHIP:ENGINES { 
    IF engine:IGNITION {
      SET totalThrust TO totalThrust + engine:THRUST. 
      SET engineCount TO engineCount + 1.
    }
  }
  IF engineCount = 0 { RETURN 0. }.
  RETURN totalThrust / engineCount.
}

////
// Calculate the ships' current radius.
// @RETURN - Scalar - Ship's curent orbital radius in M.
////
FUNCTION telemetry_performance_radius {
  RETURN SHIP:BODY:RADIUS + SHIP:ALTITUDE.
}


////
// Calculate the pull of gravit on the ship.
// @RETURN - Scalar - Acceleration due to gravity in m/s^2.
////
FUNCTION telemetry_performance_pull {
  LOCAL radius IS telemetry_performance_radius().

  RETURN CONSTANT:G * SHIP:BODY:MASS * SHIP:MASS / radius ^ 2.
}

////
// Calculate the ship's current maximum available acceleration.
// @RETURN - Scalar - Ship's current maximum acceleration due to thrust in m/s^2.
////
FUNCTION telemetry_performance_available_accel {
  LOCAL t IS telemetry_performance_available_thrust().
  LOCAL m IS SHIP:MASS.

  RETURN (t / m).
}

////
// Calculate the ship's current acceleration, taking throttle position and other
// factors such as thrust limiter into account.
// @RETURN - Scalar - Ship's current acceleration due to thrust in m/s^2.
////
FUNCTION telemetry_performance_current_accel {
  LOCAL t IS telemetry_performance_current_thrust().
  LOCAL m IS SHIP:MASS.

  RETURN (t / m).
}

////
// Calculate the ship's exaust velocity if all activated engines were
// at full throttle.
////
FUNCTION telemetry_performance_avg_exhaust_velocity {
  LOCAL _eng IS 0.
  LOCAL total_v IS 0.
  LOCAL eng_cnt IS 0.
  LOCAL answer IS FALSE.

  LIST engines IN _eng.
  FOR engine IN _eng {
    IF engine:IGNITION AND NOT engine:FLAMEOUT {
      SET total_v TO total_v + (engine:ISP * CONSTANT:g0).
      SET eng_cnt TO eng_cnt + 1.
    }
  }
  if eng_cnt = 0 { SET eng_cnt TO 1. }
  SET answer TO total_v / eng_cnt.
  syslog:msg(
    "Calculate average exhaust velocity is " + answer + " m/s^2.", 
    syslog:level:debug, 
    "telemetry:performance:avgEv"
  ).
  RETURN answer.
}

////
// Calculate the ship's acceleration at the given mass if all activated
// engines were at full throttle.
////
FUNCTION telemetry_performance_accel_at_mass {
  PARAMETER m IS SHIP:MASS.
  LOCAL answer IS FALSE.
  LOCAL t IS telemetry_performance_available_thrust().
  SET answer TO t / m.
  syslog:msg(
    "Calculated acceleration at mass " + m + " kg is " + answer + " m/s^2.",
    syslog:level:debug,
    "telemetry:performance:accelAtMass"
  ).
  RETURN answer.
}

////
// Get the thrust vector of the current stage.
////
FUNCTION telemetry_performance_thrustvector {

  LOCAL _eng IS FALSE.
  LOCAL thisEngine IS FALSE.
  LOCAL thisStage IS STAGE:NUMBER.
  LOCAL computeEngine IS LIST().
  LOCAL totalThrust IS 0.
  LOCAL thrustVector IS V(0, 0, 0).

  LIST ENGINES IN _eng.
  FOR thisEngine IN _eng {
    IF thisEngine:STAGE >= STAGE:NUMBER {
      IF thisEngine:IGNITION AND NOT thisEngine:FLAMEOUT {
        SET totalThrust TO totalThrust + thisEngine:THRUST.
        computeEngine:ADD(thisEngine).
      }
    }
  }
  FOR thisEngine IN computeEngine {
    // Find out how much this engine contributes to total thrust.
    LOCAL thrustPct IS thisEngine:THRUST / totalThrust.
    // Create an additive vector.
    IF thisEngine:HASGIMBAL {
      SET thisEngine:GIMBAL:LOCK TO TRUE.
    }
    LOCAL thisVec IS thisEngine:FACING:FOREVECTOR * thrustPct.
    IF thisEngine:HASGIMBAL {
      SET thisEngine:GIMBAL:LOCK TO FALSE.
    }
    SET thrustVector TO thrustVector + thisVec.
    SET thrustVector:MAG TO thrustVector:MAG + thisEngine:THRUST.
  }
  RETURN thrustVector.
}
