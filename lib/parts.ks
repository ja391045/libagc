////
// Library for dealing with parts.
////
boot:require("parts/engines").
boot:require("parts/controlsurfaces").
boot:require("parts/solarpanels").

GLOBAL parts IS LEXICON(
  "engines",           _engines,
  "controlSurfaces",   parts_controlsurfaces,
  "solarpanels",       parts_solarpanels,
  "toggleIntakes",     parts_toggle_intakes@,
  "allFuelCells",      parts_all_fuel_cells@,
  "startFuelCells",    parts_start_fuel_cells@,
  "stopFuelCells",     parts_stop_fuel_cells@,
  "act",               parts_act@,
  "event",             parts_event@,
  "getField",          parts_get_field@,
  "getFuelCellStatus", parts_get_fuel_cell_status@
).

////
// Get the status of a fuel cell.  For now we have to exclude FuelCellArray(s) from this
// because of a bug.
// @PARAM fuelcell - The fuel cell Part or PartModule to examine.
// @RETURN the status of the fuel cell, or a blank string if no status was found.
////
FUNCTION parts_get_fuel_cell_status {
  PARAMETER fuelCell.

  LOCAL nm IS FALSE.

  RETURN parts_get_field(fuelCell, "fuel cell", "ModuleResourceConverter").
}

////
// Toggle all the intakes.
// This doesn't even work for some reason.
////
FUNCTION parts_toggle_intakes {
  FOR _m IN SHIP:MODULESNAMED("ModuleResourceintake") {
    _m:DOACTION("toggle intake", TRUE).
  }
}

////
// Find all fuel cells.
// @RETURN - A List of PartModules belonging to attached fuel cells.
////
FUNCTION parts_all_fuel_cells {
  LOCAL cells is LIST().
  LOCAL pms IS SHIP:MODULESNAMED("ModuleResourceConverter").
  LOCAL pm IS FALSE.

  FOR pm IN pms {
    IF pm:PART:NAME = "FuelCell" OR pm:PART:NAME = "FuelCellArray" {
      cells:ADD(pm).
    }
  }

  IF syslog:logLevel >= syslog:level:debug {
    LOCAL foundNames IS LIST().
    FOR pm IN cells {
      foundNames:ADD(pm:PART:TITLE).
    }
    syslog:msg("Lookup of fuel cells found '" + foundNames:JOIN(", ") + ".", syslog:level:debug, "parts:findFuelCells").
  }
  RETURN cells.
}

////
// Start fuell cells.
// @PARAM cells - A list of ModuleResourceConverter PartModules or Parts that have ModuleResourceConverter.
FUNCTION parts_start_fuel_cells {
  PARAMETER cells.
  parts_act(cells, "start fuel cell", "ModuleResourceConverter").
}

FUNCTION parts_stop_fuel_cells {
  PARAMETER cells.
  parts_act(cells, "stop fuel cell", "ModuleResourceConverter", FALSE).
}

////
// Perform an event on a part(s) if applicable.
// @PARAM parts - A List of Parts or PartModules.
// @PARAM action - The name of the action to perform.
// @PARAM module - If parameter parts is a list of Part structures, then specify the module name.
// @PARAM value - The boolean value to pass in to the action ivnokation.
////
FUNCTION parts_event {
  PARAMETER parts.
  PARAMETER event.
  PARAMETER module IS "none".
	PARAMETER value IS TRUE.

  LOCAL skip IS FALSE.
  LOCAL m IS FALSE.

  FOR p IN parts {
    SET skip TO FALSE.
    IF p:ISTYPE("Part") {
      syslog:msg("Event request on " + p:TITLE + ".", syslog:level:debug, "parts:event").
			IF p:HASMODULE(module) {
      	SET m TO p:GETMODULE(module).
			} ELSE {
		    SET skip TO TRUE.
        SET m TO False.
        syslog:msg(
          "Skipping event '" + event + "' of " + p + ". Part " + p:TITLE + " does not have module " + module  + ".",
          syslog:level:info,
          "parts:event"
        ).
      }
    } ELSE IF p:ISTYPE("PartModule") {
      syslog:msg("Event request on " + p:PART:TITLE + ".", syslog:level:debug, "parts:event").
      SET m TO  p.
    } ELSE {
      SET skip TO TRUE.
      SET m TO FALSE.
      syslog:msg(
        "Skipping event '" + event + "' of " + p + ". Cannot use type " + p:TYPENAME + ".",
        syslog:level:info,
        "parts:event"
      ).
    }

    IF NOT skip {
      IF m:HASEVENT(event) {
        syslog:msg(
          "Performing event '" + event + "' on " + m:PART:TITLE + ".",
          syslog:level:info,
          "parts:event"
        ).
        m:DOEVENT(event).
      } ELSE {
        LOCAL allEvents IS m:ALLEVENTNAMES:JOIN("','").
        syslog:msg(
          "Action request '" + event + "' is not applicable to " + m:PART:TITLE + ". Allowed events are '" + allEvents + "'.",
          syslog:level:error,
          "parts:event"
        ).
      }
    }
  }
}

////
// You almost certainly want to do an event, not an action. Perform an action on a part(s) if applicable.
// @PARAM parts - A List of Parts or PartModules.
// @PARAM action - The name of the action to perform.
// @PARAM module - If parameter parts is a list of Part structures, then specify the module name.
// @PARAM value - The boolean value to pass in to the action ivnokation.
////
FUNCTION parts_act {
  PARAMETER parts.
  PARAMETER action.
  PARAMETER module IS "none".
	PARAMETER value IS TRUE.

  LOCAL skip IS FALSE.
  LOCAL m IS FALSE.

  FOR p IN parts {
    SET skip TO FALSE.
    IF p:ISTYPE("Part") {
      syslog:msg("Action request on " + p:TITLE + ".", syslog:level:debug, "parts:act").
			IF p:HASMODULE(module) {
      	SET m TO p:GETMODULE(module).
			} ELSE {
		    SET skip TO TRUE.
        SET m TO False.
        syslog:msg(
          "Skipping '" + action + "' of " + p + ". Part " + p:TITLE + " does not have module " + module  + ".",
          syslog:level:info,
          "parts:act"
        ).
      }
    } ELSE IF p:ISTYPE("PartModule") {
      syslog:msg("Action request on " + p:PART:TITLE + ".", syslog:level:debug, "parts:act").
      SET m TO p.
    } ELSE {
      SET skip TO TRUE.
      SET m TO FALSE.
      syslog:msg(
        "Skipping '" + action + "' of " + p + ". Cannot use type " + p:TYPENAME + ".",
        syslog:level:info,
        "parts:act"
      ).
    }

    IF NOT skip {
      IF m:HASACTION(action) {
        syslog:msg(
          "Performing action '" + action + "' on " + m:PART:TITLE + ".",
          syslog:level:info,
          "parts:act"
        ).
        m:DOACTION(action, value).
      } ELSE {
        LOCAL allActions IS m:ALLACTIONNAMES:JOIN("','").
        syslog:msg(
          "Action request '" + action + "' is not applicable to " + m:PART:TITLE + ". Allowed actions are '" + allActions + "'.",
          syslog:level:error,
          "parts:act"
        ).
      }
    }
  }
}

////
// obtain the value of a part's field.
// @PARAM part - The Part or PartModule to obtain the field from.
// @PARAM fieldName - The name of the field to obtain.
// @PARAM module - The name of the module to get field from, only required if part is a Part and not a PartModule.
// @RETURN - The value of the field if found, and an empty string if not.
////
FUNCTION parts_get_field {
  PARAMETER part.
  PARAMETER fieldName.
  PARAMETER module IS "".

  LOCAL m IS FALSE.

  IF part:ISTYPE("Part") {
    syslog:msg("Get field request on '" + part:TITLE + "'.", syslog:level:debug, "parts:getField").
    IF part:HASMODULE(module) {
      SET m TO part:GETMODULE(module).
    } ELSE {
      syslog:msg("Part " + part:TITLE + " does not have module '" + module + "'.", syslog:level:error, "parts:getField").
      RETURN "".
    }
  } ELSE IF part:ISTYPE("PartModule") {
    SET m TO part.
  } ELSE {
      syslog:msg("Can not obtain field, '" + part:TYPENAME + "' is not a Part or PartModule.", syslog:level:error, "parts:getField").
      RETURN "".
  }

  IF m:HASFIELD(fieldName) {
    RETURN m:GETFIELD(fieldName).
  } else {
    syslog:msg("PartModule " + m:NAME + " has no field '" + fieldName = "'.", syslog:level:error, "parts:getField").
    RETURN "".
  }
}
