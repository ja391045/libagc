////
// Visually display some telemetry elements.
////

GLOBAL telemetry_visual IS LEXICON(
    "positionAt",    telemetry_visual_positionAt@,
    "trueAnomalyAt", telemetry_visual_trueAnomaly@,
    "trueAnomaly",   telemetry_visual_trueAnomaly@
).

////
// Draw an arrow on the map pointing to _ship's position at the given
// time.
// @PARAM _ship  - The ship to get the position for.
// @PARAM ut     - The universal time to make the prediciton at, can be Scalar or TimeStamp.
// @PARAM _color - The color to draw the vector.
//// 
FUNCTION telemetry_visual_positionAt {
    PARAMETER _ship.
    PARAMETER ut.
    PARAMETER _color IS GREEN.

    LOCAL pos IS positionAt(_ship, ut).
    LOCAL vel IS velocityAt(_ship, ut):ORBIT.

    
    RETURN VECDRAW(pos, vel, _color, _ship:NAME).

}

////
// Draw an arrow pointing to the specified ships true anomaly.
// @PARAM _ship - The ship to draw for.
// @PARAM _label - The label to put on the arrow.
// @PARAM _color - The color the arrow should be.
// @RETURN - An initialized vecdraw object.
////
FUNCTION telemetry_visual_trueAnomaly {
    PARAMETER _ship IS SHIP.
    PARAMETER _label IS S.
    PARAMETER _color IS BLUE.

    LOCAL b_vec IS _ship:ORBIT:BODY:POSITION.
    LOCAL s_vec IS _ship:ORBIT:POSITION.
    LOCAL label IS "True Anomaly [" + _label + "]: Current is " + _ship:ORBIT:TRUEANOMALY.
    LOCAL diff_vec IS s_vec - b_vec.
    LOCAL display_vec IS diff_vec / diff_vec:MAG.
    

    FUNCTION origin_updater { RETURN _ship:ORBIT:BODY:POSITION. }
    RETURN VECDRAW(origin_updater@, display_vec, _color, label).
}

////
// Draw an arrow to the specified ship's true anomaly at some point in the future.
// @PARAM _ship - The ship to draw for.
// @PARAM ut     - The time to make the prediction for, can be a scalar or TimeStamp.
// @PARAM _label - The label to put on the arrow.
// @PARAM _color - The color the arrow should be.
// @RETURN - An initialized vecdraw object.
////
FUNCTION telemetry_visual_trueAnomalyAt {
    PARAMETER _ship IS SHIP.
    PARAMETER ut IS TIMESTAMP(TIME:SECONDS + SHIP:ORBIT:PERIOD / 2).
    PARAMETER _label IS SHIP:NAME.
    PARAMETER _color IS GREEN.

    IF ut:ISTYPE("Scalar") { SET ut TO TIMESTAMP(ut). }.
    LOCAL b_vec IS _ship:ORBIT:BODY:POSITION.
    LOCAL s_obt IS ORBITAT(_ship, ut).
    LOCAL s_vec IS s_obt:POSITION.
    LOCAL label IS "True Anomaly: [" + _label + "]" + ut:FULL + " is " + s_obt:TRUEANOMALY.
    LOCAL diff_vec IS s_vec - b_vec.
    LOCAL display_vec IS diff_vec / diff_vec:MAG.

    FUNCTION origin_updater { RETURN _ship:ORBIT:BODY:POSITITION. }

    RETURN VECDRAW(origin_updater@, display_vec, _color, label).
}
