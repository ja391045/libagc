////
// KSP seems to really to handle things in degrees.  Here's some functions
// for those cases where it makes sense to use radians.
////

GLOBAL math_helper_rad IS LEXICON(
    "cos", math_helper_rad_cos@,
    "sin", math_helper_rad_sin@,
    "tan", math_helper_rad_tan@
).



////
// Wrap the COS function for radians.
// @PARAM angle - The angle in radians.
// @RETURN - The cosine of the angle in radians.
////
FUNCTION math_helper_rad_cos {
  PARAMETER angle.

  RETURN COS(angle * CONSTANT:RADTODEG) * CONSTANT:DEGTORAD.
}

////
// Wrap the SIN function for radians.
// @PARAM angle - The angle in radians.
// @RETURN - The sine of the angle in radians.
////
FUNCTION math_helper_rad_sin {
    PARAMETER angle.

    RETURN SIN(angle * CONSTANT:RADTODEG).
}

////
// Wrap the TAN function for radians.
// @PARAM angle - The angle in radians.
// @RETURN - The tangent of the angle in radians.
////
FUNCTION math_helper_rad_tan {
    PARAMETER angle.

    RETURN TAN(angle * CONSTANT:RADTODEG).
}