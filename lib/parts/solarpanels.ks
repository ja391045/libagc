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
  LOCAL koperFound IS SHIP:MODULESNAMED("KopernicusSolarPanel").
  LOCAL names IS LIST().

  for _mod_panel in koperFound {
    found:ADD(_mod_panel).
  }

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
  
  LOCAL _has_actions IS LIST().
  LOCAL _has_events IS LIST().

  for p in panels {
    if p:HASACTION("extend solar panel") {
      _has_actions:ADD(p).
    }
    if p:HASEVENT("extend solar panel") {
      _has_events:ADD(p).
    }
  }

  parts_act(_has_actions, "extend solar panel").
  parts_event(_has_events, "extend solar panel").
}

////
// Retract solar panels.  If solar panels are not deployable, but still
// like the 'ModuleDeployableSolarPanel' module, like the OX-SAT, then
// this can still be called, it will just do nothing.
// @PARAM panels - A list of parts or partmodules to operate on.
////
FUNCTION parts_solarpanels_retract {
  PARAMETER panels.

  LOCAL _has_actions IS LIST().
  LOCAL _has_events IS LIST().

  for p in panels {
    if p:HASACTION("extend solar panel") {
      _has_actions:ADD(p).
    }
    if p:HASEVENT("extend solar panel") {
      _has_events:ADD(p).
    }
  }

  parts_act(_has_actions, "retract solar panel").
  parts_event(_has_events, "retract solar panel").
}
