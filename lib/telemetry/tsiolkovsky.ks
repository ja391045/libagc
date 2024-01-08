////
// Library which calculates Tsiolkovsky equations and derivatives.
////

boot:require("syslog").

GLOBAL telemetry_tsiolkovsky IS LEXICON(
  "fuelMass", telemetry_tsiolkovsky_fuel_mass@
).

FUNCTION telemetry_tsiolkovsky_fuel_mass {
  PARAMETER delta_v IS 0.
  PARAMETER initialMass IS SHIP:MASS.

  LOCAL inv_dv IS delta_v * -1.
  LOCAL avg_ve IS telemetry_performance_avg_exhaust_velocity().
  LOCAL answer IS FALSE.

  IF avg_ve = 0 { SET avg_ve TO 1. }


  SET answer TO initialMass - (initialMass * CONSTANT:E ^ ( inv_dv / avg_ve)). 
  syslog:msg(
    "Mass of fuel required for " + delta_v + "m/s is " + answer + " mt.",
    syslog:level:debug,
    "telemetry:tsiolkovsky:fuelMass"
  ).
  RETURN answer.

}
