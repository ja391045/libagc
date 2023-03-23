////
// Kepler's math.
////
boot:require("math/helper").
boot:require("std").

GLOBAL math_kepler IS LEXICON(
    "visViva",             math_kepler_vis_viva@,
    "timeFromShip",        math_kepler_time_from_ship@,
    "timeFromPeri",        math_kepler_time_from_peri@,
    "eccentricAnomaly",    math_kepler_eccentric_anomaly@,
    "meanAnomaly",         math_kepler_mean_anomaly@,
    "meanMotion",          math_kepler_mean_motion@
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
// Calculate the eccentric anomaly given the true anomaly.  This should work for elliptic and
// hyperbolic orbits.  Parabolic orbits are not yet implemented.
// @PARAM f - The true anomaly in degrees in the rage [0-360], any value greater than 360 will be
//            wrapped (i.e. 721 degrees = 1 degrees).
// @PARAM _obt - The orbit to calculate the eccentric anoomaly for.
// @RETURN - The eccentric anomaly in degrees.
////
FUNCTION math_kepler_eccentric_anomaly {
    PARAMETER f.        
    PARAMETER _obt IS SHIP:ORBIT.

    SET f TO math:helper:wrapTo360(f).
    LOCAL _e IS _obt:ECCENTRICITY.
    LOCAL ea IS 361.
    
    IF _e < 1 {
        // eliptical
        SET ea TO (2 * ARCTAN( SQRT( ( 1 - _e ) / ( 1 + _e ) ) * TAN( f / 2 ) )).
    } ELSE IF _e > 1  {
        // hyperbolic
        SET ea TO (math:helper:arccosh( ( _e + COS(f) ) / ( 1 + _e * COS(f) ) )).
    }
    //parabolic
    syslog:msg(
        "Cannot calculate eccentric anomaly of parabolic orbit. Not yet implemented.",
        syslog:level:crit,
        "math:kepler:eccentricAnomaly"
    ).
    RETURN ea.
}

////
// Given a true anomaly, calculate te mean anomaly. Currently this only works on elliptical and hyperbolic 
// orbits.  Parabolics aren't yet implemented.
// @PARAM f - The true anomaly in degrees [ 0 < 360 ].  Any degree > 360 will be wrapped.
// @PARAM _obt - The orbit to calculate in.
// @RETURN - The mean anomaly in degrees.
////
FUNCTION math_kepler_mean_anomaly {
    PARAMETER f.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL ea IS math_kepler_eccentric_anomaly(f, _obt).
    LOCAL _e IS _obt:ECCENTRICITY.

    IF ea > 360 {
        RETURN ea. // parabolics not yet implemented.
    }
    IF _e < 1 {
        // eliptical
        RETURN (ea - _e * SIN(ea)).// * CONSTANT:RADTODEG.
    } 
    // hyperbolic
    RETURN (_e * math:helper:sinh(ea) - ea).// * CONSTANT:RADTODEG.
}


////
// Calculate the mean motion of the orbit specified.
// @PARAM _obt - The orbit to calculate for.
// @RETURN - The mean motino of the orbit.
////
 FUNCTION math_kepler_mean_motion {
    PARAMETER _obt.

    RETURN 360 / obt:PERIOD.
 }


////
// Estimate the time in seconds from a the ship's "current" position to the true anomaly given.
// Since the vessel is always in motion, you can't really do this well. That is where 
// ORBIT:MEANANOMALYATEPOCH and ORBIT:EPOCH come in to play.  Though it is unwise to explicitly
// pass these in since the game does it's level best keep them updated.  However, if you are going
// to use the output of this function to create a node, do it very fast.
//
// The basic idea here is to take the Mean Anomaly minus Mean Anomaly at epoch and divide by Mean
// Motion.  This will give us a time from which we must then subtract the difference between now and
// the epoch at which Mean Anomaly At Epoch was created.  
//
// @PARAM f                  - The anomaly to measure time until in degrees.  If more than 360 degrees are 
//                             given then it will be wrapped, and whole orbital periods will be added for each 
//                             additional 360.
// @PARAM _obt               - The orbit to examine.
// @PARAM meanAnomalyAtEpoch - The mean motion at epoch.  By default, this is taken from the _obt structure, 
//                             and you probably want that.  The reason is it is parameterized is so that we
//                             can capture it's value as soon as the function is called.
// @PARAM epoch              - The time that meanAnomalyAtEpoch was taken.  Like meanAnomalyAtEpoch this is taken
//                             from the _obt strucutre provided so that an immediate capture of the value can be taken.
// @PARAM now                - This instant in time, parameterized so that it is capture immediately.
// @RETURN The time in seconds it will take to reach the given mean anomaly.
////
FUNCTION math_kepler_time_from_ship {
    PARAMETER f.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER meanAnomalyAtEpoch IS _obt:MEANANOMALYATEPOCH.
    PARAMETER epoch IS _obt:EPOCH.
    PARAMETER now IS TIME:SECONDS.

    LOCAL epoch_diff IS now - epoch.
    LOCAL additional_orbits IS FLOOR(f / 360).
    LOCAL true_f IS math:helper:wrapTo360(f).
    LOCAL _n IS math_kepler_mean_motion(_obt).
    LOCAL _m IS math_kepler_mean_anomaly(true_f).

    LOCAL eta_with_epoch IS ( _m - meanAnomalyAtEpoch ) / _n.
    LOCAL _eta IS eta_with_epoch - epoch_diff.
    IF _eta < 0 { SET _eta TO _eta + _obt:PERIOD. }.
    SET _eta TO _eta + additional_orbits * _obt:PERIOD.
    RETURN _eta.
}

////
// Estimate the time it will take an object to travel from the orbit periapsis to the given
// true anomaly.
// @PARAM trueAnomaly - The anomaly to measure time until in degrees [-180 < 0 < 180].
// @PARAM _obt        - The orbit to measrue in.
// @RETURN            - The time in seconds it takes the ship to travel from periapsis to the given anomaly.
////
FUNCTION math_kepler_time_from_peri {
    PARAMETER trueAnomaly.
    PARAMETER _obt IS SHIP:ORBIT.
    
    LOCAL _n IS math_kepler_mean_motion(_obt).
    LOCAL _m IS math_kepler_mean_anomaly(trueAnomaly).
    LOCAL _eta IS _m / _n.
    RETURN _eta.   
}