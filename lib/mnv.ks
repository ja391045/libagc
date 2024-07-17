////
// library for manuever node manipulation.
///

boot:require("telemetry").
boot:require("math").
boot:require("syslog").
boot:require("staging").
boot:require("mnv/node").
boot:require("mnv/rendesvouz").
boot:require("mnv/rcs").
boot:require("std/list").

////
// Everything in this library should try to utilize these speed limits
// when one vessel approaches another vessel.  In each step it takes 
// 50 seconds to traverse the distance.
////
GLOBAL mnv_speed_limits IS LEXICON (
// distance, velocity
  5,    0.1,
  20,   0.2,
  50,   0.5,
  100,  1.0,
  200,  2.0,
  300,  3.0,
  400,  4.0,
  500,  5.0,
  1000, 10.0,
  5000, 20.0
).

GLOBAL mnv IS LEXICON(
  "node",                   mnv_node,
  "rendesvouz",             mnv_rendesvouz,
  "rcs",                    mnv_rcs,
  "speedLimits",            mnv_speed_limits,
  "getSpeedLimit",          mnv_get_speed_limit@,
  "getOptimalClosingSpeed", mnv_get_optimal_closing_speed@
).


////
// Fetch the speed limit that should be observed when two objects are within 
// a given distance of one another.
// @PARAM _distance - The proximity between two objects.
// @RETURN - The speed limit that should be observed so far as relative velocity between
//           the objects are concerned.
////
FUNCTION mnv_get_speed_limit {
  PARAMETER _distance.

  LOCAL in_distance IS ABS(_distance).
  IF NOT mnv:HASKEY("__sorted_speed_limit") {
    LOCAL raw_keys IS mnv_speed_limits:KEYS.
    std:list:mergeSort(raw_keys).
    SET mnv["__sorted_speed_limit"] TO raw_keys.
  }
  LOCAL keys IS mnv["__sorted_speed_limit"].

  FOR key in keys {
    if in_distance <= key {
      RETURN mnv_speed_limits[key].
    }
  }

  RETURN 50.00.
}

////
// Get an optimal closing speed for two objects.
// @PARAM _distance          - The distance to cover, which ostensibly is the distance between the craft plus some kind of stand-off distance.
//                             Plus some safety margin.
// @PARAM _accel             - The rate of acceleration of the craft.
// @PARAM _braking_accel     - The rate of deceleration of the craft.
// @PARAM _min_closing_speed - The minimum speed required to close. (Default: 0.1)
// @PARAM _max_closing_speed - The maximum speed allowed to close. (Default: See mnv_get_speed_limit)
// @RETURN - The optimum closing speed.
////
FUNCTION mnv_get_optimal_closing_speed {
  PARAMETER _distance.
  PARAMETER _accel.
  PARAMETER _braking_accel IS _accel.
  PARAMETER _min_closing_speed IS 0.1.
  PARAMETER _max_closing_speed IS mnv_get_speed_limit(ABS(_distance)).

  LOCAL closing_speed IS _max_closing_speed.
  LOCAL LOCK braking_distance TO (closing_speed ^ 2) / (2 * _braking_accel).
  LOCAL LOCK accel_distance TO (closing_speed ^ 2) / (2 * _accel).

           
  UNTIL (accel_distance + braking_distance) <= _distance OR closing_speed = _min_closing_speed { SET closing_speed TO closing_speed - 0.1. }
  RETURN closing_speed.
}
