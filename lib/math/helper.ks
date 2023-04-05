boot:require("syslog").
boot:require("math/helper/rad").

GLOBAL math_helper IS LEXICON (
	"close",      math_helper_close@,
  "relDiff",    math_helper_relDiff@,
  "wrapTo360",  math_helper_wrapTo360@,
  "clampTo180", math_helper_clampTo180@,
  "clampTo360", math_helper_clampTo360@,
  "cosh",       math_helper_cosh@,
  "arccosh",    math_helper_arccosh@,
  "sinh",       math_helper_sinh@,
  "arctanh",    math_helper_arctanh@,
  "tanh",       math_helper_tanh@,
  "accuDeg",    math_helper_accuracy_degrees@,
  "rad",        math_helper_rad
).

////
// As orbits get larger, one degree of orbital sweep can introduce larger and larger errors.
// This semi-arbitrary scale sets the accuracy required to get orbital results for degrees 
// based on the orbital period.  For instance, when your orbit is 30 minutes, starting a burn somewhere 
// between 0.03 and 0.04 degrees of your target start anomaly is probably okay.  If your orbit is 1 year
// long then the distance between 0.03 and 0.04 degrees is enormous.
// @PARAM _obt - The orbit to calculate for.
////
FUNCTION math_helper_accuracy_degrees {
  PARAMETER _obt IS SHIP:ORBIT.
  // Let's say for the smallest orbits, we need accuracy to the 1,000th of a degree, and the very most accurate
  // we can be 1E-8
  LOCAL _max_accuracy IS 0.0000000001.
  LOCAL _min_accuracy IS 0.0001.

  LOCAL require IS 1000 / (_obt:PERIOD ^ 2).

  IF require > _min_accuracy {
    RETURN _min_accuracy.
  }
  IF require < _max_accuracy {
    RETURN _max_accuracy.
  }
  RETURN require.
}

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
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Clamping " + _d + " to 180, result is " + clamped + ".",
      syslog:level:trace,
      "math:helper:clampTo180"
    ).
  }
  RETURN clamped.
}

////
// Take a number of degrees and clamp it to the range [0-360].
// @PARAM _d - A number of  degrees.
// @return - The number in [0-360] notation.
////
FUNCTION math_helper_clampTo360 {
  PARAMETER _d.
  LOCAL clamped IS math_helper_wrapTo360(_d).
  IF _d < 0 { SET clamped TO _d + 360. }.
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Clamping " + _d + " to 360, result is " + clamped + ".",
      syslog:level:trace,
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

  IF syslog:logLevel >= syslog:level:trace { 
      LOCAL data IS LEXICON(
          "value"    , value,
          "tolerance", tolerance,
          "standard" , standard,
          "result"   , result
      ).
      LOCAL msgTxt IS std:string:sprintf("Ensuring ${value} is within ${tolerance} units of ${standard}. Result ${result}.", data).
      syslog:msg(msgTxt, syslog:level:trace, "math:helper:close").
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

  IF syslog:logLevel >= syslog:level:trace {
      LOCAL data IS LEXICON(
          "value"    , value,
          "tolerance", (tolerance * 100),
          "standard" , standard,
          "result"   , result
      ).
      LOCAL msgTxt IS std:string:sprintf("Ensuring ${value} is within ${tolerance}% of ${standard}. Result ${result}.", data).
      syslog:msg(msgTxt, syslog:level:trace, "math:helper:relDiff").
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

  IF _d < 360 AND _d > -360 {
    RETURN _d. // nothing to do.
  }
  
  LOCAL wrapped IS 0.
  IF _d < 0 { 
    SET wrapped TO MOD(_d, -360).
  } ELSE {
    SET wrapped TO MOD(ABS(_d), 360).
  }
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Wrapping " + _d + " to 360, result is " + wrapped + ".",
      syslog:level:trace,
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
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Calculate cosh of " + _x + " is " + result + ".",
      syslog:level:trace,
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
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Calculate arccosh of " + _x + " is " + result + ".",
      syslog:level:trace,
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
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Calculated sinh of " + _x + " is " + result + ".",
      syslog:level:trace,
      "math:helper:sinh"
    ).
  }
  RETURN result.
}

////
// Calculate the hyperbolic arcsin of an angle.
// @PARAMETER _x - The number to get the hyperbolic arcsin for.
// @RETURN - The hyperbolic arcsin of the number.
////
FUNCTION math_helper_arcsinh {
  PARAMETER _x.

  SET result TO LOG( _x + SQRT( _x ^ 2 + 1  ) ).
  IF syslog:loglevel >= syslog:level:trace {
    syslog:msg(
      "Calculated arcsinh of " + _x + " is " + result + ".",
      syslog:level:trace,
      "math:helper:arcsinh"
    ).
  }
  RETURN result.
}

////
// Calculate the hyperbolic arctan of an angle.
// @PARAMETER _x  The number to get the hyperbolic arctan for.
// @RETURN - The hyperbolic arctanh of _x.
////
FUNCTION math_helper_arctanh {
  PARAMETER _x.

  RETURN 0.5 * LOG( (1 + x) / (1 - x) ).
}

////
// Calculate the hyperbolic tangent of an angle.  (This is an approximation, but it should be good enough I hope.)
// @PRAMETER _x - The number to get the hyperbolic tangent for.
// @RETURN - The hyperbolic tangent of _x.
////
FUNCTION math_helper_tanh {
  PARAMETER _x.

  LOCAL count IS 100.
  LOCAL result IS 1.
  
  FROM { LOCAL _i IS 0.} UNTIL _i >=  count STEP { SET _i TO _i + 1. } DO {
    SET result TO result * (1 + _x / count).
  }

  RETURN result.
}