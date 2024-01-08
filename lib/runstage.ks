boot:require("syslog").

GLOBAL runstage IS LEXICON (
  "preserve", runstage_preserve@,
  "load",     runstage_load@,
  "bump",     runstage_bump@,
  "stage",    0
).

////
// Store the run stage.
// @PARAM - vol      - The volume to preserve the runstage on. (Default: 1).
////
FUNCTION runstage_preserve {
  PARAMETER vol IS 1.

  LOCAL _v IS VOLUME(vol).
  IF NOT _v:EXISTS("/runstage") {
    syslog:msg("Runstage preservation file does not exist, creating.", syslog:level:debug, "runstage:preserve").
    _v:CREATE("/runstage").
  }
  LOCAL fd IS _v:OPEN("/runstage").
  fd:CLEAR().
  LOCAL _txt IS "Writing " + runstage:stage:TOSTRING + " to 1:/runstage.".
  syslog:msg(_txt, syslog:level:info, "runstage:preserve").
  fd:WRITE(runstage:stage:TOSTRING).
}

////
// Load the preserved run stage.
// @PARAM - vol - The volume to load the runstage from. (Default: 1)
////
FUNCTION runstage_load {
  PARAMETER vol IS 1.

  LOCAL db_txt IS "".
  LOCAL _rn IS 0.

  LOCAL _v IS VOLUME(vol).
  IF NOT _v:EXISTS("/runstage") {
    SET runstage:stage TO _rn.
    syslog:msg("Setting runstage to 0.", syslog:level:info, "runstage:load").
    RETURN.
  }

  SET _rn TO _v:OPEN("/runstage"):READALL:STRING:TONUMBER.
  SET db_txt TO "Setting runstage to " + _rn + ".".
  syslog:msg(db_txt, syslog:level:info, "runstage:load").
  SET runstage:stage TO _rn.
}

////
// Increment the runstage to next runstage.
////
FUNCTION runstage_bump {
  SET runstage:stage TO runstage:stage + 1.
}
