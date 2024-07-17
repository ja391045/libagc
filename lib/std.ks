boot:require("std/err").
boot:require("std/string").
boot:require("std/struct").
boot:require("std/atomic").
boot:require("std/list").

GLOBAL std IS LEXICON (
    "string",        std_string,
    "err",           std_err,
    "struct",        std_struct,
    "atomic",        std_atomic,
    "list",          _list,
    "activeVessel",  std_active_vessel@,
    "randomString",  std_random_string@,
    "mktmp",         std_mktmp@,
    "hasTarget",     std_has_target@,
    "isValidTarget", std_is_valid_target@
).

////
// Test to see if VESSEL or VESSEL:NAME string is a valid target.  Generally, a VESSEL is a valid target unless it
// ISDEAD.  Otherwise it might be helpful to see if a ship exists by name, before trying to construct VESSEL, or 
// setting the ship by name as the valid target.
// @PARAM _name - The vessel or name of the vessel to test.
// @RETURN - True if the test is a valid target, False otherwise.
////
FUNCTION std_is_valid_target {
  PARAMETER _name.

  LOCAL all_tgt IS FALSE.

  IF _name:ISTYPE("Vessel") {
    RETURN NOT _name:ISDEAD.
  } ELSE IF NOT _name:ISTYPE("String") {
    RETURN FALSE.
  }

  LIST TARGETS IN all_tgt.

  FOR this_tgt IN all_tgt {
    IF this_tgt:NAME = _name { RETURN TRUE. }
  }
  RETURN FALSE.
}


////
// Test if _test is the active vessel.
// @PARAM _test - The VESSEL to test. (Default: SHIP.)
// @RETURN - True if the ship is the active vessel return true, otherwise return false.
////
FUNCTION std_active_vessel {
  PARAMETER _test IS SHIP.

  RETURN (KUNIVERSE:ACTIVEVESSEL = _test).
}

////
// Test to see if this ship has a target set.
// @RETURN - True if the active vessel has a target, false otherwise.
////
FUNCTION std_has_target {
  RETURN (TARGET:NAME:LENGTH > 0).
}

////
// Generate a random string of characters.
// @PARAM _min_length
// @PARAM _max_length
// @PARAM _charset
// @RETURN - A string of random characters with a length between min_length and max_length, taken from charset, or FALSE if
//           _max_length < _min_length
////
FUNCTION std_random_string {
  PARAMETER _min_length IS 10.
  PARAMETER _max_length IS 10.
  PARAMETER _charset IS "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".

  LOCAL length IS _min_length.
  LOCAL random_chars IS LIST().

  IF NOT _min_length = _max_length {
    IF _max_length < _min_length {
      RETURN FALSE.
    }
    SET length TO ROUND(_min_length + RANDOM() * (_max_length - _min_length)).
  }

  FROM { LOCAL i IS length. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
    random_chars:ADD(_charset[FLOOR(RANDOM() * _charset:LENGTH)]).
  }
  
  RETURN random_chars:JOIN("").
}

////
// Get a pathname for a temporary file.
// @PARAM _id - The beginning segment of the name of this tmpfile path. (Default: tmp) 
// @PARAM _ext - Any extension to add to this tmp file (i.e. .txt, .dat, .json). (Default: "").
// @PARAM _tmp_path - The path for temporary files. (Default: 1:/tmp).
////
FUNCTION std_mktmp {
  LOCAL _id IS "tmp".
  LOCAL _ext IS "".
  LOCAL _tmp_path IS "/tmp".

  LOCAL format IS "{path}/{id}-{rand}".
  LOCAL data IS LEXICON(
    "path", _tmp_path,
    "id",   _id,
    "rand", std_random_string()
  ).

  IF ext:LENGTH > 0 {
    SET format TO format + ".{ext}".
    SET data["ext"] TO _ext.
  }

  RETURN std_string_sprintf(format, data).
}

////
// Internal API
////
FUNCTION __ensure_tmpdir__ {
  LOCAL tmp_vol IS VOLUME(1).
  LOCAL tmp_path IS "/tmp".

  IF NOT tmp_vol:EXISTS(tmp_path) {
    tmp_vol:CREATEDIR(tmp_path).
  }
}

//// Init ////
__ensure_tmpdir__().
