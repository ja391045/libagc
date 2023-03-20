

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

  IF NOT volume(vol):EXISTS("/runstage") {
    volume(vol):CREATE("/runstage").
  }
  LOCAL fd IS volume(vol):OPEN("/runstage").
  fd:CLEAR().
  fd:WRITE(runstage:stage:TOSTRING).
}

////
// Load the preserved run stage.
// @PARAM - vol - The volume to load the runstage from. (Default: 1)
////
FUNCTION runstage_load {
  PARAMETER vol IS 1.

  IF NOT volume(vol):EXISTS("/runstage") {
    RETURN 0.
  }

  SET runstage:stage TO volume(vol):OPEN("/runstage"):READALL:STRING:TONUMBER.
}

////
// Increment the runstage to next runstage.
////
FUNCTION runstage_bump {
  SET runstage:stage TO runstage:stage + 1.
}
