boot:require("syslog").

GLOBAL math_helper IS LEXICON (
	"close",      math_helper_close@,
  "relDiff",    math_helper_relDiff@,
  "wrapTo360",  math_helper_wrapTo360@,
  "clampTo180", math_helper_clampTo180@,
  "clampTo360", math_helper_clampTo360@,
  "cosh",       math_helper_cosh@,
  "arccosh",    math_helper_arccosh@,
  "sinh",       math_helper_sinh@
).

////
// Take a number of degrees in range [-360 < 0 < 360] and convert it to range [-179-180], where -180 == 180. 
// @PARAM _d - A number in degress.
// @RETURN - The degress bound from [-180 - 180]
////
FUNCTION math_helper_clampTo180 {
  PARAMETER _d.
  LOCAL clamped IS _d.
  IF _d > 180 {
    SET clamped TO _d - 360.
  } ELSE IF _d < -180 {
    SET clamped TO + 360.
  }
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Clamping " + _d + " to 180, result is " + clamped + ".",
      syslog:level:debug,
      "math:helper:clampTo180"
    ).
  }
  RETURN clamped.
}

////
// Take a number of degrees in the range [-179 - 180] and clamp it to the range [0-360].
// @PARAM _d - A number in -180-180 degrees.
// @return - The number in [0-360] notation.
////
FUNCTION math_helper_clampTo360 {
  PARAMETER _d.
  LOCAL clamped IS _d.
  IF _d < 0 { SET clamped TO _d + 360. }.
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Clamping " + _d + " to 360, result is " + clamped + ".",
      syslog:level:debug,
      "math:helper:clampTo360"
    ).
  }
  RETURN clamped.
}

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

  IF syslog:logLevel > syslog:level:info { 
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

  IF syslog:logLevel > syslog:level:info {
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

////
// Wrap a direction given in degrees down a range of [-360 < 0 < 360].
// @PARAMETER _d - The number of degrees to wrap.
// @RETURN - The wrapped value once all whole revolutions removed.
////
FUNCTION math_helper_wrapTo360 {
  PARAMETER _d.
  LOCAL wrapped IS 0.
  IF _d < 0 { 
    SET wrapped TO MOD(_d, -360).
  } ELSE {
    SET wrapped TO MOD(ABS(_d), 360).
  }
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Wrapping " + _d + " to 360, result is " + wrapped + ".",
      syslog:level:debug,
      "math:helper:wrapTo360"
    ).
  }
  RETURN wrapped.
}

////
// Calculate the hyperbolic cosine of an angle.
// @PARAM _x - The number to get the hyperbolic cosine of.
// @PRETURN - Hopefully the hyperbolic cosine of _x.
////
FUNCTION math_helper_cosh {
  PARAMETER _x.

  SET result TO (CONSTANT:E ^ _x + CONSTANT:E ^ (_x * -1)) / 2.
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Calculate cosh of " + _x + " is " + result + ".",
      syslog:level:debug,
      "math:helper:cosh"
    ).
  }
  RETURN result.
}

////
// Calculate the hyperbolic arccos of an angle.
// @PARAM _x - The number to get the hyperbolic arccos for.
// @RETURN - The hyperbolic arccos of _x.
////
FUNCTION math_helper_arccosh {
  PARAMETER _x.

  SET result TO LN(x + SQRT(_x ^ 2 - 1)).
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Calculate arccosh of " + _x + " is " + result + ".",
      syslog:level:debug,
      "math:helper:arccosh"
    ).
  }
  RETURN result.
}

////
// Calculate the hyperbolic sine of an angle.
// @PARAM _x - The number to get the hyperbolic sine for.
// @RETURN - The hyperbolic sine of _x.
////
FUNCTION math_helper_sinh {
  PARAMETER _x.

  SET result TO (CONSTANT:E ^ _X - CONSTANT:E ^ (_x * -1)) / 2.
  IF syslog:loglevel > syslog:level:info {
    syslog:msg(
      "Calculated sinh of " + _x + " is " + result + ".",
      syslog:level:debug,
      "math:helper:sinh"
    ).
  }
  RETURN result.
}