////
// A library for orbital rv.
////

boot:require("math").

GLOBAL mnv_rendesvouz IS LEXICON(

).

////
// Calculate the phase angle required, for transfer if both orbits were circular.  This only works
// if the ships are orbiting the same body.
// @PARAM _chaser - The ship that will be moving to rendesvouz with the target.
// @PARAM _target - The ship that the chaser will move to.
// @RETURN - The phase in angle in degrees toward prograde.
////
FUNCTION math_rendesvouz_phase_angle {
    PARAMETER _chaser IS SHIP.
    PARAMETER _target IS TARGET.

    // We need to calculate the length of time the transfer will take.
    LOCAL xferSMA IS (_chaser:ORBIT:SEMIMAJORAXIS + _target:ORBIT:SEMIMAJORAXIS) / 2.
    LOCAL xferPeriod IS  math:kepler:period(xferSMA, _chaser:ORBIT:BODY) / 2.
    LOCAL targetN IS math:kepler:meanMotion(_target:ORBIT).
    LOCAL targetTransit IS xferPeriod * targetN. // degrees of mean motion during transfer

    

}