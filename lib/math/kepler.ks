boot:require("math/kepler/orbit").
boot:require("math/kepler/anomaly").

GLOBAL math_kepler IS LEXICON(
    "orbit",   LEXICON(
                   "visViva",          math_kepler_visViva@,
                   "meanMotion",       math_kepler_meanMotion@
               ),
    "anomaly", LEXICON(
                   "trueToEccentric", math_kepler_trueToEccentric@,
                   "eccentricToMean", math_kepler_eccentricToMean@,
                   "trueToMean",      math_kepler_trueToMean@
               )
).

FUNCTION math_kepler_visViva {
    PARAMETER target_a.
    PARAMETER start_r IS SHIP:BODY:RADIUS + SHIP:ALTITUDE.
    PARAMETER start_a IS SHIP:ORBIT:SEMIMAJORAXIS.
    PARAMETER body_mu IS SHIP:ORBIT:BODY:MU.

    RETURN math_kepler_orbit["visViva"](target_a, start_r, start_a, body_mu).
}

FUNCTION math_kepler_meanMotion {
    PARAMETER mu IS SHIP:BODY:MU.
    PARAMETER semiMajorAxis IS SHIP:ORBIT:SEMIMAJORAXIS.

    RETURN math_kepler_orbit["meanMotion"](mu, semiMajorAxis).
}

FUNCTION math_kepler_trueToEccentric {
    PARAMETER eccentricity IS SHIP:ORBIT:ECCENTRICITY.
    PARAMETER trueAnomaly IS SHIP:ORBIT:TRUEANOMALY.

    RETURN math_kepler_anomaly["trueToEccentric"](eccentricity, trueAnomaly).
}

FUNCTION math_kepler_eccentricToMean {
    PARAMETER eccentricity IS SHIP:ORBIT:ECCENTRICITY.
    PARAMETER eccentricAnomaly IS math_kepler_trueToEccentric(SHIP:ORBIT:ECCENTRICITY, SHIP:ORBIT:TRUEANOMALY).

    RETURN math_kepler_anomaly["eccentricToMean"](eccentricity, eccentricAnomaly).
}

FUNCTION math_kepler_trueToMean {
    PARAMETER eccentricity IS SHIP:ORBIT:ECCENTRICITY.
    PARAMETER trueAnomaly IS SHIP:ORBIT:TRUEANOMALY.

    RETURN math_kepler_anomaly["trueToMean"](eccentricity, trueAnomaly).
}
