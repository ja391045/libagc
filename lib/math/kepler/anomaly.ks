boot:require("syslog").

GLOBAL math_kepler_anomaly IS LEXICON (
    "trueToEccentricDeg", math_kepler_anomaly_trueToEccentric@,
    "eccentricToMeanDeg", math_kepler_anomaly_eccentricToMean@,
    "trueToMeanDeg", math_kepler_anomaly_trueToMean@
).

FUNCTION math_kepler_anomaly_trueToEccentric {
    PARAMETER eccentricity.
    PARAMETER trueAnomaly.

    LOCAL result IS 2 * ARCTAN(SQRT(( 1 - eccentricity ) / ( 1 + eccentricity )) * TAN(trueAnomaly / 2)).
    
    IF syslog:loglevel >= syslog:level:debug {
      LOCAL msg IS "TrueToEccentric(" + eccentricity + ", " + trueAnomaly + ") = " + result + ".".
      syslog:msg(msg, syslog:level:debug, "math:kepler:anomaly").
    }

    RETURN result.
}

FUNCTION math_kepler_anomaly_eccentricToMean {
    PARAMETER eccentricity.
    PARAMETER eccentricAnomaly.

    LOCAL result IS eccentricity - eccentricAnomaly * SIN(ec) * CONSTANT:RADTODEG.

    IF syslog:loglevel >= syslog:level:debug {
      LOCAL msg IS "EccentricToMean(" + eccentricity + ", " + eccentricAnomaly + ") = " + result + ".".
      syslog:msg(msg, syslog:level:debug, "math:kepler:anomaly").
    }
    
    RETURN result.
}

FUNCTION math_kepler_anomaly_trueToMean {
    PARAMETER eccentricity.
    PARAMETER trueAnomaly.

    LOCAL result IS math_kepler_anomaly_trueToMean(eccentricity, math_kepler_anomaly_trueToEccentric(eccentricity, trueAnomaly)).

    IF syslog:loglevel >= syslog:level:debug {
      LOCAL msg IS "TrueToMean(" + eccentricity + ", " + trueAnomaly + ") = " + result + ".".
      syslog:msg(msg, syslog:level:debug, "math:kepler:anomaly").
    }

    RETURN result.
}
