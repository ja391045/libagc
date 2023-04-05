////
// Kepler's math.
////
boot:require("math/helper").
boot:require("math/geo").
boot:require("std").

GLOBAL math_kepler IS LEXICON(
    "visViva",             math_kepler_vis_viva@,
    "timeFromShip",        math_kepler_time_from_ship@,
    "timeFromPeri",        math_kepler_time_from_peri@,
    "eccentricAnomaly",    math_kepler_eccentric_anomaly@,
    "meanAnomaly",         math_kepler_mean_anomaly@,
    "meanMotion",          math_kepler_mean_motion@,
    "radiusAt",            math_kepler_radiusat@,
    "period",              math_kepler_period@,
    "minOrbitRadius",      math_kepler_min_orbit_r@,
    "minOrbitVelocity",    math_kepler_min_orbit_v@,
    "elapsedTime",         math_kepler_elapsed_time@,
    "trueAnomalyAt",       math_kepler_true_anomaly_at@,
    "meanToEccentric",     math_kepler_mean_to_eccentric@,
    "meanToEccentricR",    math_kepler_mean_to_eccentric_r@,
    "eccentricToTrue",     math_kepler_eccentric_to_true@,
    "focusSeparation",     math_kepler_focus_separation@
).

////
// Get the velocity required to achieve the minimum orbit altitude.
// @PARAM _body - The body to examine.
// @RETURN - The raw velocity required to achieve the minimum orbit, does not
//           factor in gravity or drag.
////
FUNCTION math_kepler_min_orbit_v {
    PARAMETER _body IS SHIP:BODY.

    LOCAL min_r IS math_kepler_min_orbit_r(_body).   // Both radius and semimajor axis for circular orbit.
    RETURN __math_kepler_vis_viva(_body:MU, min_r, min_r).
}

////
// Return the minimal orbital radius.  This isn't really keplerian math, but it
// kinda fits in this library.
// @PARAM _body - The body to calculate for.
// @RETURN - The minimum radius required in order to orbit _body.
////
FUNCTION math_kepler_min_orbit_r {
    PARAMETER _body IS SHIP:ORBIT:BODY.
    
    if _body:ATM:EXISTS {
        RETURN _body:RADIUS + _body:ATM:HEIGHT + 1.
    }
    RETURN _body:RADIUS + math:geo:peaks[_body:NAME] + 1.
}

////
// Calculate an orbital period.  In most cases, it's best to use ORBIT or any ORBIT
// structure to get this.  However, sometimes, like when calculating a rendezvous you'd
// have to create a temporary node to get the desired orbital period.   That's a hassle, so
// this quick and dirty function can be easily called instead.
// @PARAMETER _a    - Semi-major axis.
// @PARAMETER _body - The body being orbited.
// @RETURN - The period of the orbit described around the body described.
////
FUNCTION math_kepler_period {
    PARAMETER _a.
    PARAMETER _body IS SHIP:BODY.
    
    RETURN 2 * CONSTANT:PI * SQRT(a ^ 3 / _body:MU).
}

////
// Use Vis Viva to get the orbital radius of a vessel at a future point in time..
// @PARAM _ut   - The universal time to predict.
// @PARAM _ship - The ship to calculate for.
// @RETURN - The radius of the orbit at a given point in time.
////
FUNCTION math_kepler_radiusat {
    PARAMETER ut IS TIME:SECONDS.
    PARAMETER _ship IS SHIP.

    LOCAL _ut IS 0.
    IF ut:ISTYPE("TimeStamp") {
        SET _ut TO ut:SECONDS. 
    } ELSE {
        SET _ut TO ut.
    }

    LOCAL _obt IS ORBITAT(_ship, _ut).
    LOCAL _e IS _obt:ECCENTRICITY.
    LOCAL _ta IS _obt:TRUEANOMALY.
    LOcaL _a IS _obt:SEMIMAJORAXIS.
    LOCAL _r IS _a * ( 1 - _e ^ 2 ) / (1 + _e * COS(_ta)).

    IF syslog:logLevel >= syslog:level:debug {
        LOCAL _ts IS TIMESTAMP(_ut).
        syslog:msg(
            "Calculated radius of " + _ship:NAME  + " to be " + _r + " at " + _ts:FULL + ".",
            syslog:level:debug,
            "math:kepler:radiusAt"
        ).
    }
    RETURN _r.
}

////
// @API - Internal.
// An implementation of the vis viva equation with no context. It just needs the terms.
// @PARAM _mu - The main body's mass * the Gravitation constant.
// @PARAM _r  - The orbital radius.
// @PARAM _a  - The semi-major axis.
// @RETURN - The velocity required of the given orbital parameters.
FUNCTION __math_kepler_vis_viva {
    PARAMETER _mu.
    PARAMETER _r.
    PARAMETER _a.

    RETURN SQRT( _mu * ( (2/_r) - (1/_a) ) ).
}

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

    LOCAL start IS __math_kepler_vis_viva(_obt:BODY:MU, start_radius, _obt:SEMIMAJORAXIS).
    LOCAL end IS __math_kepler_vis_viva(_obt:BODY:MU, start_radius, target_a).
    RETURN end - start.
}


////
// Calculate the eccentric anomaly given the true anomaly.  This should work for elliptic and
// hyperbolic orbits.  Parabolic orbits are not yet implemented.
// @PARAM f - The true anomaly in degrees in the rage [0-360], any value greater than 360 will be
//           wrapped (i.e. 721 degrees = 1 degrees).
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
        SET ea TO ARCCOS( ( _e + COS(f) ) / ( 1 + _e * COS(f) ) ).
        // SET ea TO (2 * ARCTAN( SQRT( ( 1 - _e ) / ( 1 + _e ) ) * TAN( f / 2 ) )).
    } ELSE IF _e > 1  {
        // hyperbolic
        SET ea TO (math:helper:arccosh( ( _e + COS(f) ) / ( 1 + _e * COS(f) ) )).
    } ELSE {
        //parabolic
        syslog:msg(
        "Cannot calculate eccentric anomaly of parabolic orbit. Not yet implemented.",
        syslog:level:crit,
        "math:kepler:eccentricAnomaly"
        ).
    }
    RETURN ea.
}

////
// A re-entrant wrapper around math_kepler_mean_to_eccentric.  This function does a few iterations
// at a time, and yields for the specified period to allow other threads to execute.  For the rest
// of the description @SEE math_kepler_mean_to_eccentric.  This function can still block your mainline
// code, which is likely what you want.  However, background conditions can still continue to run.  If
// you don't want your mainline code blocked by this, then set _blocking to FALSE, and periodically check
// for a global named mean_to_eccentric_result, and check the "converged" value.
// @PARAM _m            - @SEE math_kepler_mean_to_eccentric _m.
// @PARAM _obt          - @SEE math_kepler_mean_to_eccentric _obt.
// @PARAM _max          - @SEE math_kepler_mean_to_eccentric _max.
// @PARAM _its_per_call - How many iterations to run before taking a break to allow other things to
//                        execute.  (Default: 100)
// @PARAM  _break_span  - How long each break should be in seconds.
// @PARAM _ig           - @SEE math_kepler_mean_to_eccentric _ig.
////
FUNCTION math_kepler_mean_to_eccentric_r {
    PARAMETER _m.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER _max IS 1000.
    PARAMETER _t IS "auto-generated".
    PARAMETER _its_per_call IS 100.
    PARAMETER _break_span IS 3.
    PARAMETER _ig IS "auto-generated".
    PARAMETER _blocking IS TRUE.

    // We don't want processes to stack up here.
    IF _break_span < 1 {
        SET _break_span TO 1.
    }

    LOCAL _nextStart IS TIME:SECONDS.
    LOCAL _result IS 0.
    LOCAL _left IS _max - _its_per_call.
    LOCAL _override_guess IS _ig.
    LOCAL _done IS FALSE.

    WHEN TIME:SECONDS > _nextStart THEN {
        SET _result to math_kepler_mean_to_eccentric(_m, _obt, _its_per_call, _t, _override_guess).
        IF _left > _its_per_call {
            SET _left TO _left - _its_per_call.
        } ELSE {
            SET _its_per_call TO _left.
            SET _left to 0.
        }
        IF _result:converged OR _left <= 0 OR (_result:hasError AND NOT _result:hasResult) {
            // The function has converged or otherwise can't proceed.
            SET _done TO TRUE. 
            RETURN FALSE. 
        }
        IF NOT _blocking {
            GLOBAL _mean_to_eccentric_result IS _result.
            syslog:msg("Non-blocking mode has set result global.", syslog:level:debug, "math:kepler:meanToEccentricR").
        }
        SET _override_guess to _result:result.
        SET _nextStart TO TIME:SECONDS + _break_span.
        syslog:msg(
            "Completed " + _its_per_call + " iterations, remaining " + _left + ".", 
            syslog:level:debug,
            "math:kepler:meantoEccentricR"
        ).
        RETURN TRUE.
    }

    IF _blocking {
        syslog:msg("Blocking mode is waiting for result to complete.", syslog:level:debug, "math:kepler:meanToEccentricR").
        WAIT UNTIL _done.
        RETURN _result.
    }
}

////
// Calculate the eccentric anomaly from a meean anomaly using a Newton-Raphson iteration.
// This will be an expensive operation.  If the orbit is hyperbolic, or highly eccentric, 
// the number of iterations will need to be cranked up.
// ** WARNING ** - This is a very expensive, very time consuming function.  There is a reentrant
//                 wrapper to this function that should be used instead that allows other threads
//                 and conditions to execute in between chunks of processing.
// ** Note **: For hyperbolic orbits, you are definitely going to want to crank up the iterations
//             or reduce the tolerance of your guess, or both.
// ** Note **: If this function fails to converge, the most likely culprit is the initial guess is too
//             inaccurate.  There may be other methods to generate an initial guess.  You can pass in your
//             own guess that is more accurate to the situation, or you can increase the iterations and/or
//             decrese the desired accuracy (i.e. tolerance).
// @PARAMETER _m   - The mean anomaly.
// @PARAMETER _obt - The orbit to calculate in.
// @PARAMETER _max - The maximum iterations to allow to achieve an accurate result.
// @PARAMETER _t   - The tolerance required before the answer is considered "right".
// @PARAMETER _ig  - The initial guess, this function contains a number of methods of generating the initial
//                   guess, but you can pass in your own if required.  (Default: "auto-generated")
// @RETURN - The answer found or a string if an error occurs.  Test to see if a string was returned in order
//           to determine if an error occured.
////
FUNCTION math_kepler_mean_to_eccentric {
    PARAMETER _m.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER _max IS 1000.
    PARAMETER _t IS "auto-generated".
    PARAMETER _ig IS "auto-generated".

    LOCAL result IS LEXICON("hasError", FALSE, "converged", FALSE).

    FUNCTION derive_mean_relation_eccentric {
        PARAMETER _e.    // The eccentricitcy of the orbit.
        PARAMETER _ea.   // The eccentric anomaly in degrees.

        if _e < 1 {
            // Elliptical orbit case.
            RETURN _ea - _e * SIN(_ea).
        } ELSE {
            // Hyperbolic orbit case.
            RETURN _e * math:helper:sinh(_ea) - _ea.          
        }
    }

    LOCAL _i IS 0.
    LOCAL _e IS _obt:ECCENTRICITY.
    IF _t:ISTYPE("String") AND _t = "auto-generated" { 
        // Obtain the accuracy required by the size of the orbit.  The bigger the orbit, the 
        // more meters between every degree.
        SET _ TO math:helper:accuDeg(_obt). 
    }.
    IF _ig:ISTYPE("String") AND _ig = "auto-generated" { 
        // generate an initial guess
        IF _e < 0.01 {
            // Near circular
            SET _i TO _m.
        } ELSE if _e < 0.1 {
            // A little less than near circular.
            SET _i to _m + _e * SIN(_m) / 2.
        } ELSE IF _e < 0.9 {
            // Eliptical
            LOCAL sin_E IS SIN(_m) * SQRT(1 - _e ^ 2) / (1 + _e * COS(_m)).
            LOCAL cos_E IS (_e + COS(_m)) / (1 + _e * COS(_m)).
            SET _i TO ARCTAN2(sin_E, cos_E).
        } ELSE IF _e > 1 {
            // hyperbolic
            SET _i TO math:helper:arcsinh( SQRT( ( _e + 1 ) / ( -1 - _e ) ) ).
        } ELSE {
            // parabolic, not yet implemented.  Need more math.
            syslog:msg("Attempt to caclualte for a parabolic orbit, not yet implemented.", syslog:level:error, "math:kepler:meanToEccentric").
            SET result["hasError"] TO TRUE.
            SET result["error"] TO "Parabolic orbits not yet implemented.".
            SET result["hasResult"] TO FALSE.
            RETURN result.
        }
    } ELSE {
        SET _i TO _ig.
    }
    

    LOCAL msg IS "Mean anomaly is " + _m + " initial guess based off eccentricity=" + ROUND(_obt:ECCENTRICITY, 4) + " is " + _i + ". ".
    syslog:msg(msg, syslog:level:debug, "math:kepler:meanToEccentric").

    // Try to converge.
    LOCAL count IS 0.
    LOCAL _error IS ABS(math_kepler_mean_anomaly(_i, _obt) - _m).
    syslog:msg("Initial error is " + _error + " allowed error is < " + _t + ".", syslog:level:debug, "math:kepler:meanToEccentric").
    LOCAL _startIter IS TIME:SECONDS.
    UNTIL _error < _t {
        ////
        // As _i approaches zero (if it's a very small number), it can short circuit the
        // the whole process.  If _i is a high number, and _i is less than zero, then that's as
        // close as we can get in this case.  This can also happen as it approaches 360, because 360
        // gets wrapped to 0.
        ////
        IF math:helper:close(ABS(_i), 360, 0.01) OR math:helper:close(ABS(_i), 0, 0.01) {
            SET _error TO 0.
            BREAK.         
        }
        SET _new_i TO math_kepler_mean_anomaly(_i, _obt) - _m.
        IF syslog:logLevel >= syslog:level:debug {
            syslog:msg("Mean anomaly difference is " + _new_i + ".", syslog:level:debug, "math:kepler:meanToEccentric").
        }
        ////
        // As _i approaches zero (if it's a very small number), it can short circuit the
        // the whole process.  If _i is a high number, and _i is less than zero, then that's as
        // close as we can get in this case.  This can also happen as it approaches 360, because 360
        // gets wrapped to 0.
        ////
        IF math:helper:close(ABS(_i), 360, 0.01) OR math:helper:close(ABS(_i), 0, 0.01) {
            SET _error TO 0.
            BREAK.         
        }
        IF _e > 1 {
            if _new_i > 0 {
                // This should always be negative for hyperbolic orbits.
                SET _new_i TO _new_i * -1.
            }
        }
        SET _i TO _i - ( _new_i /  derive_mean_relation_eccentric(_e, _i) ).
        IF syslog:logLevel >= syslog:level:debug {
            syslog:msg("Mean anomaly difference over derivative is " + _i + ".", syslog:level:debug, "math:kepler:meanToEccentric").
        }
        SET _error TO ABS(math_kepler_mean_anomaly(_i, _obt) - _m).
        if syslog:logLevel >= syslog:level:trace { 
            LOCAL msg IS "Calculation this iteration is " + _i + " and error width is " + _error + ".  Target error is < " + _t + ".".
            syslog:msg(msg, syslog:level:trace, "math:kepler:meanToEccentric"). 
        }
        IF count >= _max {
            SET result["hasError"] TO TRUE.
            SET result["error"] TO "Calculation failed to converge in " + count + " iterations.".
            BREAK.
        }
        SET count TO count + 1.
    }
    LOCAL elapsed IS TIMESPAN(TIME:SECONDS - _startIter).
    SET result["converged"] TO (_error < _t).
    LOCAL msg is "".
    IF result:converged {
        SET msg TO "Converged eccentric anomaly from mean in " + count + " iterations. Elapsed time " + elapsed:FULL + ".".
    } ELSE {
        SET msg TO "Failed to converge eccentric anomaly from mean in " + count + " iterations. Elapsed time " + elapsed:FULL + ".".
    }
    syslog:msg(msg, syslog:level:info, "math:kepler:meanToEccentric").
    SET result["hasResult"] TO TRUE.
    SET result["result"] TO _i.
    SET result["converged"] TO (_error < _t).
    RETURN result.
}

////
// Calculate a True Anomaly from an Eccentric Anomaly.
// @PARAM _ea  - The eccentric anomaly.
// @PARAM _obt - The orbit to calculate in (Default: SHIP:ORBIT)
// @RETURN - The calculated true anomaly.
////
FUNCTION math_kepler_eccentric_to_true {
    PARAMETER _ea.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL _e IS _obt:ECCENTRICITY.
    IF ABS(1 - _e) < 0.0000000001 {
        RETURN _ea.
    }
    LOCAL _f IS 361.
    IF _e < 1 {
        // Eliptical case.
        LOCAL tan_half_f IS SQRT( ( 1 + _e) / (1 - _e) ) * TAN(_ea / 2).
        SET _f TO 2 * ARCTAN2(tan_half_f, 1).
    } ELSE IF _e > 1 {
        // Hyperbolic case.  
        LOCAL tanh_half_f IS SQRT( (_e + 1) / (_e - 1) ) * math:helper:tanh(_ea / 2).
        SET _f TO 2 * math:helper:arctanh(tanh_half_f).
    } // ELSE {
        // Parabolic case, for now just return 3160
    //}

    IF _f < 0 {
        SET _f TO _f + 360.
    }
    RETURN _f.
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
        RETURN ea - _e * SIN(ea) * CONSTANT:RADTODEG.
    } 
    // hyperbolic
    RETURN _e * math:helper:sinh(ea) - ea * CONSTANT:RADTODEG.
}

////
// Calculate the mean motion of the orbit specified.
// @PARAM _obt - The orbit to calculate for.
// @RETURN - The mean motino of the orbit.
////
 FUNCTION math_kepler_mean_motion {
    PARAMETER _obt IS SHIP:ORBIT.

    RETURN SQRT(_obt:BODY:MU / _obt:SEMIMAJORAXIS ^ 3) * CONSTANT:RADTODEG.
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

////
// Get the elapsed time between two true anomalies.
// @PARAM _start - The starting true anomaly in degrees.
// @PARAM _end   - The ending true anomaly in degrees.
// @PARAM _obt   - The orbit to measure in.  The TRUEANOMALY value of this orbit is ignored. (Default: SHIP:ORBIT)
// @RETURN - The time elapsed between the given true anomalies.
////
FUNCTION math_kepler_elapsed_time {
    PARAMETER _start.
    PARAMETER _end.
    PARAMETER _obt IS SHIP:ORBIT.

    LOCAL mm IS math_kepler_mean_motion(_obt).
    LOCAL addTime IS FLOOR(_start / 360) * _obt:PERIOD + FLOOR(_end / 360) * _obt:PERIOD.
    LOCAL real_start IS math:helper:wrapTo360(_start).
    LOCAL real_end IS math:helper:wrapTo360(_end).
    LOCAL start_ma IS math_kepler_mean_anomaly(real_start, _obt).
    LOCAL end_ma IS math_kepler_mean_anomaly(real_end, _obt).
    LOCAL delta_ma IS start_ma - end_ma.
    
    RETURN ABS( delta_ma / mm ).
}


////
// Calculate your ship's true anomaly at some point in the future or past.  This function will try
// to take manuever nodes into account and pretend they were executed perfectly.
// @PARAMETER _time - The time to examine in universal time.
// @PaRAMETER _obt  - The orbit to calculate in.  (Default: SHIP:ORBIT)
////
FUNCTION math_kepler_true_anomaly_at {
    PARAMETER _time.
    PARAMETER _obt IS SHIP:ORBIT.
    PARAMETER break_time IS 3.

    LOCAL refTime IS TIME:SECONDS.
    IF _time:hassuffix("seconds") { SET _time TO _time:SECONDS. }.

    LOCAL currentTa IS _obt:TRUEANOMALY.
    FOR _nd IN ALLNODES {
        IF _nd:TIME <= _time {
            SET currentTa TO _nd:ORBIT:TRUEANOMALY.
            SET refTime TO _nd:TIME.
            SET _obt TO _nd:ORBIT.
        }
    }

    LOCAL elapsedTime IS _time - refTime.
    LOCAL _addDeg IS 0.
    SET _addOrbits TO FLOOR(ABS(elapsedTime) / _obt:PERIOD).
    SET _addDeg TO _addOrbits * 360.
    SET _realEt TO MOD(elapsedTime, _obt:PERIOD).
    IF _realEt = 0 { RETURN currentTa. } // Evenly divisble multiple of the orbit period will: yield current position.

    // Convert current true anomaly to mean anomaly. and add the mean motion that occurs
    // during the given timeframe.
    LOCAL currentMa IS math_kepler_mean_anomaly(currentTa, _obt).
    LOCAL _mm IS math_kepler_mean_motion(_obt).
    LOCAL futureMa IS currentMa + _mm * _realEt.

    if syslog:logLevel >= syslog:level:debug {
        syslog:msg(
            "Finding true anomaly at " + elapsedTime + " seconds from now. " +
            "This time period has been reduced by " + _addOrbits + " orbital periods. " +
            "This in turn yields a future (or past) mean anomaly of " + futureMa + ", " +
            "relative current mean anomaly of " + currentMa + ".",
            syslog:level:debug,
            "math:kepler:trueAnomalyAt"
        ).
    }
    // Get the eccentric anomaly from the future mean anomaly.
    LOCAL futureEa IS 0.
    IF _obt:ECCENTRICITY < 0.9 {
        SET futureEa TO math_kepler_mean_to_eccentric_r(futureMa, _obt, (ABS(_addOrbits) + 1) * 2000, "auto-generated", 100, break_time).
    } ELSE {
        SET futureEa TO math_kepler_mean_to_eccentric_r(futureMa, _obt, (ABS(_addOrbits) + 1) * 3000, "auto-generated", 100, break_time).
    }
    IF futureEa:converged AND futureEa:hasResult {
        RETURN math_kepler_eccentric_to_true(futureEa:result, _obt) + _addDeg.
    }
    RETURN futureEa.
}


////
// Calculate the distance between the primary focus and conjugate focus of the orbital ellipse.
// @PARAM - _obt - The orbit to calcualte.
// @RETURN - The distance between the primary focus and conjugate focus of the eliptical orbit,
//           if given a circular orbit, like e < 0.00000001 or so, then the distance betwween the
//           foci is going to be zero, or near enough to make division a problem.
////
FUNCTION math_kepler_focus_separation {
    PARAMETER _obt IS SHIP:ORBIT.

    RETURN 2 * _obt:SEMIMAJORAXIS * _obt:ECCENTRICITY.
}