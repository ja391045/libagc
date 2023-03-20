////
// Library for dealing with controlsurface parts.
////
boot:require("syslog").

GLOBAL parts_controlsurfaces IS LEXICON(
  "lockAll", parts_controlsurfaces_lockall@,
  "enableYaw", parts_controlsurfaces_enable_yaw@,
  "enableRoll", parts_controlsurfaces_enable_roll@,
  "enablePitch", parts_controlsurfaces_enable_pitch@
).

////
// Lock all the control surfaces.
// @PARAM - The list of parts to operate over.
////
FUNCTION parts_controlsurfaces_lockall {
  PARAMETER p.
  LOCAL _p IS FALSE.

  FOR _p IN p {
    IF _p:HASMODULE("ModuleControlSurface") {
      syslog:msg("Disabling all controls on surface " + _p:TITLE + ".", syslog:level:debug, "parts:controlsurface:lockAll").
      _p:GETMODULE("ModuleControlSurface"):DOACTION("deactivate all controls", TRUE).
    }
  }
}

////
// Enable YAW controls on parts.
// @PARAM p - The list parts to enable.
////
FUNCTION parts_controlsurfaces_enable_yaw {
  PARAMETER p.
  LOCAL _p IS FALSE.

  FOR _p IN p {
    IF _p:HASMODULE("ModuleControlSurface") {
      syslog:msg("Enabling yaw controls on surface " + _p:TITLE + ".", syslog:level:debug, "parts:controlsurface:lockAll").
      _p:GETMODULE("ModuleControlSurface"):DOACTION("activate yaw control", TRUE).
    }
  }
}

////
// Enable roll controls on parts.
// @PARAM p - The list parts to enable.
////
FUNCTION parts_controlsurfaces_enable_roll {
  PARAMETER p.
  LOCAL _p IS FALSE.

  FOR _p IN p {
    IF _p:HASMODULE("ModuleControlSurface") {
      syslog:msg("Enabling roll controls on surface " + _p:TITLE + ".", syslog:level:debug, "parts:controlsurface:lockAll").
      _p:GETMODULE("ModuleControlSurface"):DOACTION("activate roll control", TRUE).
    }
  }
}

////
// Enable pitch controls on parts.
// @PARAM p - The list parts to enable.
////
FUNCTION parts_controlsurfaces_enable_pitch {
  PARAMETER p.
  LOCAL _p IS FALSE.

  FOR _p IN p {
    IF _p:HASMODULE("ModuleControlSurface") {
      syslog:msg("Enabling pitch controls on surface " + _p:TITLE + ".", syslog:level:debug, "parts:controlsurface:lockAll").
      _p:GETMODULE("ModuleControlSurface"):DOACTION("activate pitch control", TRUE).
    }
  }
}
