boot:require("syslog").

global math_kepler_orbit IS LEXICON(
    "visViva",    math_kepler_orbit_visViva@,
    "meanMotion", math_kepler_orbit_meanMotion@
).

////
// Calculate the delta v needed to reach target semi-major axis.
// @PARAM start_r   - The radius of the position at burn.
// @PARAM target_a  - The target semi-major axis.
// @PARAM start_a   - The semi-major axis of the starting orbit.
// @PARAM body_mu   - The central body's gravitational constant.
// @RETURN          - The delta-V required in m/s.
////
FUNCTION math_kepler_orbit_visViva {
    PARAMETER target_a.
    PARAMETER start_r.
    PARAMETER start_a.
    PARAMETER body_mu.

    LOCAL start IS SQRT( body_mu * ( (2/start_r) - (1/start_a) ) ).
    LOCAL end IS SQRT( body_mu * ( (2/start_r) - (1/target_a) ) ).
    LOCAL result IS end - start.

    IF syslog:loglevel >= syslog:level:debug {
      LOCAL msg IS "VisViva from " + start_a + "m to " + target_a + "m is  " + result + "m/s^2.".
      syslog:msg(msg, syslog:level:debug, "math:kepler:orbit").
    }

    RETURN result.
}

FUNCTION math_kepler_orbit_meanMotion {
    PARAMETER mu.
    PARAMETER semiMajorAxis.

    LOCAL result IS SQRT( mu / semiMajorAxis ^ 3) * CONSTANT:RADTODEG.

    IF syslog:loglevel >= syslog:level:debug {
      LOCAL msg IS "MeanMotion of orbit with semi-major axis of " + semiMajorAxis + " is " + result + " degrees.".
      syslog:msg(msg, syslog:level:debug, "math:kepler:orbit").
    }

    RETURN result.
}
