////
// Library for calculating ETAs.
////

boot:require("math/kepler").
boot:require("math/geo").
boot:require("syslog").

GLOBAL math_eta IS LEXICON(
    "periapsis",  math_eta_periapsis@,
    "apoapsis",   math_eta_apoapsis@,
    "periToApo",  math_eta_peri_to_apo@,
    "periToPeri", math_eta_peri_to_peri@
).


////
// Calculate ETA to Periapsis.  This function is used mostly
// for testing math:kepler functions.  The answer should match
// *very close* to an immediate call to SHIP:ORBIT:ETA:PERIAPSIS.
////
FUNCTION math_eta_periapsis {
    PARAMETER _obt IS SHIP:ORBIT.

    return math:kepler:timeFromShip(0, _obt).
}

////
// Calculate ETA to Apoapsis.  This function is used mostly for testing
// math:kepler functions.  The answer should match *very close* to an 
// immediate call to SHIP:ORBIT:ETA:APOAPSIS.
////
FUNCTION math_eta_apoapsis {
    PARAMETER _obt IS SHIP:ORBIT.

    return math:kepler:timeFromShip(180, _obt).
}

////
// Calculate orbitable time from Periapsis to Apoapsis.  This function
// is used mostly for testing math:kepler.  The answer should match
// 0.5 * SHIP:ORBIT:PERIOD.
////
FUNCTION math_eta_peri_to_apo {
    PARAMETER _obt IS SHIP:ORBIT.

    return math:kepler:timeFromPeri(180, _obt).
}

////
// Calculate the orbitable time from Periapsis to Periapsis. This function
// is used mostly for testing math:kepler, the answer should be 0.
////
FUNCTION math_eta_peri_to_peri {
    PARAMETER _obt IS SHIP:ORBIT.

    return math:kepler:timeFromPeri(0, _obt).
}


FUNCTION etaToLatLng {

}