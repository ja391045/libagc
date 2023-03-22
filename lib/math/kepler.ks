////
// Kepler's math.
////
boot:require("math/helper").
boot:require("std").

GLOBAL math_kepler IS LEXICON(
    "visViva",             math_kepler_vis_viva@,
    "eccentricAnomalyRad", math_kepler_eccentric_anomaly_rad@,
    "eccentricAnomalyDeg", math_kepler_eccentric_anomaly_deg@,
    "meanAnomalyRad",      math_kepler_mean_anomaly_rad@,
    "meanAnomalyDeg",      math_kepler_mean_anomaly_deg@,
    "meanMotionRad",       math_kepler_mean_motion_rad@,
    "meanMotionDeg",       math_kepler_mean_motion_deg@,
    "timeFromShip",        math_kepler_time_from_ship@,
    "timeFromPeri",        math_kepler_time_from_peri@
).


////
// Vis Viva equation for determining deltaV of orbital radii changes.
// @PARAM target_a - The target semimajor axis after burn.
// @PARAM _obt - The orbit structure of the orbit the burn will take place in.
// @PARAM start_radius - The radius of the spacecraft's orbit at the time of the burn.
////
FUNCTION math_kepler_vis_viva {
    PARAMETER target_a.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER start_radius IS _obt:BODY:RADIUS + SHIP:ALTITUDE.

    LOCAL start IS SQRT( _obt:BODY:MU * ( (2/start_radius) - (1/obt:SEMIMAJORAXIS) ) ).
    LOCAL end IS SQRT( _obt:BODY:MU * ( (2/start_radius) - (1/target_a) ) ).
    RETURN end - start.
}

////
// Eccentric Anomaly.  Calculate the eccentric anomaly from a given true anomaly.
// @PARAM trueAnomaly - This *must* be expressed in degrees between -180 and 180.  The calculation
//                      for any true anomaly from periapsis "up to" the apoapsis is in positive 
//                      degrees 0 to 180, with 180 degrees being the true anomaly of apoapsis. Once you 
//                      pass the apoapsis and heading back "down to" the periapsis, then degrees count
//                      from -179 up to 0
// @PRAM   _obt       - The orbit to calculate for, default is SHIP:ORBIT.
// @RETURN - The eccentric anomaly in *radians*.  If trueAnomaly is a positive value, this function will
//           yield the Eccentric Anomaly from Periapsis to TrueAnomaly.  If the value is negative, this
//           function will yield the Eccentric Anomaly from True Anomaly to Periapsis.  If the result is
//           > 2 * PI, then the function failed.
////
FUNCTION math_kepler_eccentric_anomaly_rad {
    PARAMETER trueAnomaly. 
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL cos_ta_rad IS COS(trueAnomaly) * CONSTANT:DEGTORAD.
    LOCAL _e IS _obt:ECCENTRICITY.

    LOCAL absEccAnomaly IS 0. 
    SET _base to (_e + cos_ta_rad) / (1 + _e * cos_ta_rad).
    LOCAL result IS 2 * CONSTANT:PI + 1.

    IF _obt:ECCENTRICITY < 1 {
        SET absEccAnomaly TO ARCCOS(_base).
    } ELSE IF _obt:ECCENTRICITY > 1 {
        SET absEccAnomaly TO math:helper:arccosh(_base).
    } ELSE {
        // Parabolic orbit (_e = 1) - not implemented.
        syslog:msg:crit(
            "Parabolic Eccentric Anomaly is not implemented, halting.", 
            syslog:level:crit, 
            "math:kepler:eccentricAnomalyRad"
        ).
        RETURN result.
    }

    IF trueAnomaly < 0 {
        SET result TO absEccAnomaly * -1.
    }
    SET result TO absEccAnomaly.
    IF syslog:loglevel > syslog:level:info {
        LOCAL _args IS LEXICON(
            "ta", trueAnomaly,
            "result", result,
            "E", _e
        ).
        LOCAL msgfmt IS "Calculate eccentric anomaly for true ${ta} with eccentricity ${E}, result: ${result}.".
        LOCAL msg IS std:string:sprintf(msgfmt, _args).
        syslog:msg(msg, syslog:level:debug, "math:kepler:eccentricAnomaly").
    }
}

////
// @SEE math_kepler_eccentric_anomaly_rad
// @PARAM trueAnomaly - @SEE math_kepler_eccentric_anomaly_rad
// @PARAM _obt - @SEE math_kepler_eccentric_anomaly_rad
// @RETURN - @SEE math_kepler_eccentric_anomaly_rad, except this return is in degrees [-180 < 0 < 180]
////
FUNCTION math_kepler_eccentric_anomaly_deg {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL ea_deg IS math_kepler_eccentric_anomaly_rad(trueAnomaly, _obt) * CONSTANT:RADTODEG.
    IF ea_deg > 2 * COnSTANT:PI * CONSTANT:RADTODEG {
        RETURN ea_deg.
    }
    LOCAL clamped IS math:helper:clampTo180(clamped).
    RETURN clamped.
}

////
// Calculate the mean anomaly from a given true anomaly.
// @PARAM trueAnomaly -  @SEE math_kepler_eccentric_anomaly_rad for restrictions.
// @PARAM _obt - The orbit to solve in.
// @RETURN - The mean anomaly in terms of the true anomaly.
////
FUNCTION math_kepler_mean_anomaly_rad {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL ecc_a_rad IS math_kepler_eccentric_anomaly_rad(trueAnomaly, _obt).
    LOCAL _e IS _obt:ECCENTRICITY.
    LOCAL result IS 2 * CONSTANT:PI + 1.
    

    IF _obt:ECCENTRICITY < 1 {
        SET result TO ecc_a_rad - _e * (sin(trueAnomaly) * CONSTANT:DEGTORAD). 
    } ELSE IF _obt:ECCENTRICITY < 1 {
        SET result TO _e * math:helper:sinh(ecc_a_rad) - ecc_a_rad.
    } ELSE{
        syslog:msg(
            "Parabolic mean anomaly is not yet implemented.",
            syslog:level:crit,
            "math:kepler:meanAnomalyRad"
        ).
        RETURN result.
    }

    IF syslog:loglevel > syslog:level:info {
        syslog:msg(
            "Calculate mean anomaly of " + trueAnomaly + " is " + result + ".",
            syslog:level:debug,
            "math:kepler:meanAnomalyRad"
        ).
    }

    RETURN result.
}

////
// @SEE math_kepler_mean_anomaly_rad
////
FUNCTION math_kepler_mean_anomaly_deg {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL result IS math_kepler_mean_anomaly_rad(trueAnomaly, _obt).
    RETURN result * CONSTANT:RADTODEG.
}

////
// calculate the mean motion of the given orbit.
// @PARAM _obt - The orbit to calculate.
// @RETURN - The mean motion of the body in the specified orbit in degrees per second.
////
FUNCTION math_kepler_mean_motion_deg {
    PARAMETER _obt.

    RETURN math_kepler_mean_motion_rad(_obt) * CONSTANT:RADTODEG.
}

////
// calculate the mean motion of the given orbit.
// @PARAM _obt - The orbit to calculate.
// @RETURN - The mean motion of the body in the specified orbit in radians.
////
FUNCTION math_kepler_mean_motion_rad {
    PARAMETER _obt.

    RETURN 2 * CONSTANT:PI / _obt:PERIOD.
}

////
// Estimate the time in seconds from a the ship's "current" position to the true anomaly given.
// Since the vessel is always in motion, you can't really do this well. That is where 
// ORBIT:MEANANOMALYATEPOCH and ORBIT:EPOCH come in to play.  Though it is unwise to explicitly
// pass these in since the game does it's level best keep them updated.  However, if you are going
// to use the output of this function to create a node, do it very fast.
//
// @PARAM trueAnomaly - The anomaly to measure time until in degrees [-180 < 0 < 180].
// @PARAM -obt - The orbit to examine.
// @PARAM meanMotionEpoch - The mean motion at epoch.
// @PARAM epoch - The epoch.
// @RETURN The time in seconds it will take to reach the given mean anomaly.
////
FUNCTION math_kepler_time_from_ship {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER meanAnomalyAtEpoch IS _obt:MEANANOMALYATEPOCH.
    PARAMETER epoch IS _obt:EPOCH.

    LOCAL now IS TIME:SECONDS.
    LOCAL _n IS math_kepler_mean_motion_rad(_obt).
    LOCAL _m IS math_kepler_mean_anomaly_rad(trueAnomaly).
    
    LOCAL _mae IS meanAnomalyAtEpoch * CONSTANT:DEGTORAD.
    LOCAL _t IS ((_m - _mae) / _n).
    SET _t TO _t - (epoch - now).
    PRINT "TA: " + trueAnomaly + ", M: " + _m + ", MM: " + _n + ", T: " + _t + ".".
    IF _t < 0 {
       RETURN _t + _obt:PERIOD.
    }
    RETURN _t - _obt:PERIOD.
}

////
// Estimate the time it will take the vessel to travel from the orbit periapsis to the given
// true anomaly.
// @PARAM trueAnomaly - The anomaly to measure time until in degrees [-180 < 0 < 180].
// @PARAM _obt - The orbit to measrue in.
// @RETURN - The time in seconds it takes the ship to travel from periapsis to the given anomaly.
////
FUNCTION math_kepler_time_from_peri {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.
    
    LOCAL _n IS math_kepler_mean_motion_rad(_obt).
    LOCAL _m IS math_kepler_mean_anomaly_rad(trueAnomaly).
    LOCAL _t IS _m / _n.
    PRINT "_t IS " + _t.
    IF _t < 0 {
        RETURN _t + _obt:PERIOD.
    }
    RETURN _t.
}