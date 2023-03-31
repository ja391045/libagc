////
// A library for orbital rv.
////

boot:require("math").

GLOBAL mnv_rendesvouz IS LEXICON(

).

////
// Sweep the chaser ship's orbit and get a time to transfer to target
// orbit at each point on the sweep.   This is an expensive function, so
// use as sparingly and narrowly as possible.
// @PARAM _chaser - The vessel initiating the rendezvous.
// @PARAM _target - The target of the rendezvous.
// @PARAM _start  - The relative to the orbital period to start "0" would be periapsis.
// @PARAM _end    - A timespan in seconds relative to the sweep start when it should end.
// @RETURN - A structure correlating the orbital time from periapsis to both a true anomaly,
//           as well as the time it would take to transfer from the true anomaly to the target
//           orbit.
////
FUNCTION mnv_rendesvouz_sweep {
    PARAMETER _chaser IS SHIP.
    PARAMETER _target IS TARGET.
    PARAMETER _start  IS 0.
    PARAMETER _end IS ORBIT:PERIOD.

    LOCAL start_ta IS 0.
} 