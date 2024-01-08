////
// A library for orbital rv.
////

boot:require("math").
boot:require("syslog").
boot:require("std").

GLOBAL mnv_rendesvouz IS LEXICON(
    "coplanarPhaseAngle", mnv_rendesvouz_coplanar_phase_angle@
).

////
// Calculate the current phase angle between two objects.  This really only works when orbits
// are coplanar (or close enough).
// @PARAM _chaser - The ship that will be moving to rendesvouz with the target.
// @PARAM _target - The ship that the chaser will move to.
// @RETURN - The phase angle in degrees toward prograde.
////
FUNCTION mnv_rendesvouz_coplanar_phase_angle {
    PARAMETER _chaser IS SHIP.
    PARAMETER _target IS TARGET.

    LOCAL t_obt IS _target:ORBIT.
    LOCAL c_obt IS _chaser:ORBIT.


    IF (c_obt:HASSUFFIX("BODY") AND t_obt:HASSUFFIX("BODY")) AND (t_obt:BODY <> c_obt:BODY) {
        SET t_obt TO _target:BODY:ORBIT.
        SET c_obt TO _chaser:BODY:ORBIT.
    }

    LOCAL origin IS c_obt:BODY:POSITION.
    LOCAL t_vecdraw IS VECDRAW(
        { RETURN t_obt:BODY:POSITION. },
        { RETURN _target:POSITION - t_obt:BODY:POSITION. },
        RED,
        "Target",
        1.0,
        TRUE
    ).    
    LOCAL c_vecdraw IS VECDRAW(
        { RETURN c_obt:BODY:POSITION. },
        { RETURN _chaser:POSITION - c_obt:BODY:POSITION. },
        BLUE,
        "Chaser",
        1.0,
        TRUE
    ).
    LOCAL t_vec IS _target:POSITION - t_obt:BODY:POSITION.
    LOCAL c_vec IS _chaser:POSITION - c_obt:BODY:POSITION.
    RETURN VANG(t_vec, c_vec).
}
