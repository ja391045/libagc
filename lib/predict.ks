////
// Library for operations based on predictions.
////

GLOBAL predict IS LEXICON(
  "posRelBody", predict_pos_rel_body@,
  "radiusAt",   predict_radius_at@
).


////
// Predict an vessel's orbital position, relative to the central body, for a given time and orbit.
// @PARAM - utm - The universal time to make the prediction at.
// @PARAM - _ship - The ship to make the prediction for (Default: SHIP).
// @PARAM - _obt - The orbit to make the prediction for (Default: _ship:ORBIT)
////
FUNCTION predict_pos_rel_body {
  PARAMETER utm.
  PARAMETER _ship IS SHIP.
  PARAMETER _obt IS _ship:ORBIT.

  LOCAL futureShipPos IS POSITIONAT(_ship, utm).
  LOCAL futureBodyPos is POSITIONAT(_obt:BODY, utm).
  return futurePos - futureBodyPos.
}

////
// Predict a vessel's orbital radius at a given time.
// @PARAM - utm - The universal time to make the prediction at.
// @PARAM - _ship - The ship to make the prediction for (Default: SHIP).
// @PARAM - _obt - The orbit to make the prediction for (Default: _ship:ORBIT).
////
FUNCTION predict_radius_at {
  PARAMETER utm.
  PARAMETER _ship IS SHIP.
  PARAMETER _obt IS _ship:ORBIT.

  LOCAL relPos IS predict_pos_rel_body(utm, _ship, _obt).
  RETURN relPos:MAG.
}

