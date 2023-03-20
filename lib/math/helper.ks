boot:require("syslog").

GLOBAL math_helper IS LEXICON (
	"close",   math_helper_close@,
  "relDiff", math_helper_relDiff@
).

////
// Determine if two scalar values are within an absolute tolerance of one another.
// @PARAM  - value     - The value to examine.
// @PARAM  - standard  - The value to which value is compared.
// @PARAM  - tolerance - The tolerance which the values are expected to meet or exceed. (Default: 0.01)
// @RETURN - boolean   - Whether or not the two values are within tolerance of one another.
////
FUNCTION math_helper_close {
  PARAMETER value.
  PARAMETER standard.
  PARAMETER tolerance IS 0.01.

  LOCAL result IS ABS( value - standard ) <= tolerance.

  IF syslog:logLevel >= syslog:level:debug { 
      LOCAL data IS LEXICON(
          "value"    , value,
          "tolerance", tolerance,
          "standard" , standard,
          "result"   , result
      ).
      LOCAL msgTxt IS std:string:sprintf("Ensuring ${value} is within ${tolerance} units of ${standard}. Result ${result}.", data).
      syslog:msg(msgTxt, syslog:level:debug, "math:helper:close").
  }
  RETURN result.
}

////
// Determine if two scalar values are within a given percentage of each other.
// @PARAM - value - The value to examine.
// @PARAM - standard - The base value to which the first parameter is compared.
// @PARAM - tolerance - The percentage of difference allowed between the values, expressed as a decimal. (Default: 0.01)
// @RETURN - boolean - Whether or not the values are within tolerance of one another.
////
FUNCTION math_helper_relDiff {
  PARAMETER value.
  PARAMETER standard.
  PARAMETER tolerance IS 0.01.

  LOCAL result IS 0.

  SET divisor TO MAX(ABS(value), ABS(standard)).

  IF divisor = 0 {
      SET result TO TRUE.
  } else {
      SET result TO (ABS(value - standard) / divisor) <= tolerance.
  }

  IF syslog:logLevel >= syslog:level:debug {
      LOCAL data IS LEXICON(
          "value"    , value,
          "tolerance", (tolerance * 100),
          "standard" , standard,
          "result"   , result
      ).
      LOCAL msgTxt IS std:string:sprintf("Ensuring ${value} is within ${tolerance}% of ${standard}. Result ${result}.", data).
      syslog:msg(msgTxt, syslog:level:debug, "math:helper:relDiff").
  }
  RETURN result.
}
