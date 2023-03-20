////
// Module for solar panels.
////
boot:require("syslog").

GLOBAL parts_solarpanels IS LEXICON(
  "getDeployable", parts_solarpanels_get_deployable@,
  "deploy", parts_solarpanels_deploy@,
  "retract", parts_solarpanels_retract@,
  "status", parts_solarpanels_status@
).

////
// Get the status of a solar panel.
// @PARAM - The solar panel's part or partmodule.
// @RETURN - The status value of the field, or a blank string if the field is not found.
////
FUNCTION parts_solarpanels_status {
  PARAMETER panel.

  RETURN parts_get_field(panel, "status", "ModuleDeployableSolarPanel").
}

////
// Get all solar panel modules on this ship.
// @RETURN A list of PartModules.
////
FUNCTION parts_solarpanels_get_deployable {
  LOCAL found IS SHIP:MODULESNAMED("ModuleDeployableSolarPanel").
  LOCAL names IS LIST().

  if syslog:logLevel >= syslog:level:debug {
    FOR panel IN found {
      names:ADD(panel:PART:TITLE).
    }
    syslog:msg(
      "Lookup deployable solar panels, found: " + names:JOIN(",") + ".",
      syslog:level:debug,
      "parts:solarpanels:getDeployable"
    ).
  }
  RETURN found.
}

////
// Extend solar panels.  If solar panels are not deployable, but still
// like the 'ModuleDeployableSolarPanel' module, like the OX-SAT, then
// this can still be called, it will just do nothing.
// @PARAM panels - A list of parts or partmodules to operate on.
////
FUNCTION parts_solarpanels_deploy {
  PARAMETER panels.
  parts_event(panels, "extend solar panel", "ModuleDeployableSolarPanel").
}

////
// Retract solar panels.  If solar panels are not deployable, but still
// like the 'ModuleDeployableSolarPanel' module, like the OX-SAT, then
// this can still be called, it will just do nothing.
// @PARAM panels - A list of parts or partmodules to operate on.
////
FUNCTION parts_solarpanels_retract {
  PARAMETER panels.
  parts_event(panels, "retract solar panel", "ModuleDeployableSolarPanel").
}
