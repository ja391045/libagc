////
// Library for geolocations.
////
GLOBAL math_geo IS LEXICON(
    "coordsToDec", math_geo_coords_to_dec@
).

////
// Private API, initialize some constants programatically.
////
FUNCTION __math_geo_init__ {
    LOCAL _kb IS BODY("Kerbin").
    LOCAL center_east_west IS (-74.7277483360912 - -74.4908963506797 / 2) + -74.4908963506797.
    LOCAL runwayBounds IS LEXICON(
        "west",  _kb:GEOPOSITIONLATLNG(-0.048661948884938, -74.7282677884327),
        "east",  _kb:GEOPOSITIONLATLNG(-0.048661948884938, -74.4908963506797),
        "north", _kb:GEOPOSITIONLATLNG(-0.046142687134905, center_east_west),
        "south", _kb:GEOPOSITIONLATLNG(-0.051189396573565, center_east_west),
        "rp1",   _kb:GEOPOSITIONLATLNG(-0.048661948884938, -74.8090979717177),
        "rp2",   _kb:GEOPOSITIONLATLNG(-0.048661948884938, -76.3334200128002),
        "rp3",   _kb:GEOPOSITIONLATLNG(-0.048661948884938, -78.8116182956137)
    ).
    LOCAL launchPadBounds IS LEXICON(
        "center", _kb:GEOPOSITIONLATLNG(-0.0972267527711966, -74.5577015973641),
        "rp1",    _kb:GEOPOSITIONLATLNG(-0.0972267527711966, -74.8090979717177),
        "rp2",    _kb:GEOPOSITIONLATLNG(-0.0972267527711966, -76.3334200128002),
        "rp3",    _kb:GEOPOSITIONLATLNG(-0.0972267527711966, -78.8116182956137)
    ).
    SET math_geo["ksc"] TO LEXICON(
        "runway", runwayBounds,
        "launchpad", launchPadBounds
    ).
    SET math_geo["peaks"] TO LEXICON(
        "Moho",    6818,
        "Eve",     7541,
        "Gilly",   6401,
        "Kerbin",  6768,
        "Mun",     7049,
        "Minmus",  5724,
        "Duna",    8268,
        "Ike",     12738,
        "Dres",    5670,
        "Jool",    0,
        "Laythe",  6079,
        "Vall",    7985,
        "Tylo",    12904,
        "Bop",     21757,
        "Pol",     4891,
        "Eeloo",   3797
    ).
}

////
// Given degrees, minutes and seconds of latitude or longitude,
// convert this to decimal.
// @PARAM _degrees - The coordinate degrees.
// @PARAM _minutes - The coordinate minutes.
// @PARAM _seconds - The coordinate seconds.
// @PARAM _precision - Round at the given position.
// @RETURN - The coordinates expressed in decimal degrees.
////
FUNCTION math_geo_coords_to_dec {
    PARAMETER _degrees.
    PARAMETER _minutes.
    PARAMETER _seconds.
    PARAMETER _precision IS 4.

    LOCAL _min IS 1/60.
    LOCAL _sec IS 1/3600.
    RETURN ROUND(_degrees + _minutes * _min + _seconds * _sec, _precision).
}

FUNCTION timeToLatitude {
    
}
__math_geo_init__().