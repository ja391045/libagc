////
// Module for manipulation of rcs parts.
////

GLOBAL parts_rcs_traverse_direction IS LEXICON(
  "fore",      1,
  "aft",       2,
  "up",        3,
  "down",      4,
  "starboard", 5,
  "right",     5,
  "port",      6,
  "left",      6
).

GLOBAL parts_rcs_part_patterns IS LIST(".*rcs.*").

GLOBAL parts_rcs_part_default_module_names IS LIST("ModuleRCSFX").

GLOBAL parts_rcs IS LEXICON(
  "defaultPartPatterns",  parts_rcs_part_patterns,
  "defaultModuleNames",   parts_rcs_part_default_module_names, 
  "setThrustLimiter",     parts_rcs_set_thrust_limiter@,
  "storeThrustLimiter",   parts_rcs_store_thrust_limiter@,
  "restoreThrustLimiter", parts_rcs_restore_thrust_limiter@,
  "getRCSModules",        parts_rcs_get_rcs_modules@,
  "getRCSParts",          parts_rcs_get_rcs_parts@,
  "isAlignedFore",        parts_rcs_is_aligned_fore@,
  "isAlignedAft",         parts_rcs_is_aligned_aft@,
  "isAlignedUp",          parts_rcs_is_aligned_up@,
  "isAlignedDown",        parts_rcs_is_aligned_down@,
  "isAlignedStarboard",   parts_rcs_is_aligned_starboard@,
  "isAlignedPort",        parts_rcs_is_aligned_port@,
  "traverseDirection",    parts_rcs_traverse_direction,
  "getTraverseThrustFor", parts_rcs_get_traverse_thrust_for@
).


////
// calculate the amount of thrust the ship has in the given traversal direction.
// @PARAM _direction - See parts_rcs_traverse_direction keys.
// @PARAM _ship      - The ship the thruster is attached to. (Default: _ship)
// @PARAM _rcs_parts - RCS parts to look at if you've already queried them from the ship. (Default: LIST()).
// @PARAM _pattersn  - Patterns to use to fetch RCS parts if _rcs_parts is empty. (Default: See parts_rcs_parts_patterns).
////
FUNCTION parts_rcs_get_traverse_thrust_for {
  PARAMETER _direction.
  PARAMETER _ship IS SHIP.
  PARAMETER _rcs_parts IS LIST().
  PARAMETER _patterns IS parts_rcs_part_patterns.

  IF NOT parts_rcs_traverse_direction:HASKEY(_direction) {
    RETURN 0.
  }
  LOCAL x IS parts_rcs_traverse_direction[_direction].

  LOCAL rcs_parts IS _rcs_parts.
  IF rcs_parts:EMPTY {
    SET rcs_parts TO parts_rcs_get_rcs_parts(_ship, _patterns).
  }

  LOCAL this_part IS 0.
  LOCAL aligned_parts IS LIST().
  FOR this_part IN rcs_parts {  
    IF x = 1 {
      IF parts_rcs_is_aligned_fore(this_part, _ship) { aligned_parts:ADD(this_part). }
    } ELSE IF x = 2 {
      IF parts_rcs_is_aligned_aft(this_part, _ship) { aligned_parts:ADD(this_part). }
    } ELSE IF x = 3 {
      IF parts_rcs_is_aligned_up(this_part, _ship) { aligned_parts:ADD(this_part). }
    } ELSE IF x = 4 {
      IF parts_rcs_is_aligned_down(this_part, _ship) { aligned_parts:ADD(this_part). }
    } ELSE IF x = 5 {
      IF parts_rcs_is_aligned_starbaord(this_part, _ship) { aligned_parts:ADD(this_part). }
    } ELSE {
      IF parts_rcs_is_aligned_port(this_part, _ship) { aligned_parts:ADD(this_part). }
    }
  }

  IF aligned_parts:EMPTY {
    syslog:msg(
      "Could not find any RCS parts aligned with " + _direction + ".",
      syslog:level:debug,
      "parts:rcs:getTraverseThrustFor"
    ).
  } ELSE {
    syslog:msg(
      "Found " + aligned_parts:LENGTH + " thrusters that align with " + _direction + ".",
      syslog:level:debug,
      "parts:rcs:getTraverseThrustFor"
    ).
  }

  LOCAL thrust IS 0.
  FOR this_part IN aligned_parts {
    syslog:msg(
      "Adding " + this_part:AVAILABLETHRUST + " to thrust available for direction " + _direction + ".",
      syslog:level:debug,
      "parts:rcs:getTraverseThrustFor"
    ).
    SET thrust TO thrust + this_part:AVAILABLETHRUST.
  }
  syslog:msg(
    "Have " + thrust + "kN for direction " + _direction + ".",
    syslog:level:debug,
    "parts:rcs:getTraverseThrustFor"
  ).

  RETURN thrust.
}



////
// Get a list of RCS parts on the ship.
// @PARAM _ship     - The vessel to look in for RCS parts. (Default; SHIP)
// @PARAM _patterns - The pattern of names used to look for RCS parts. (Default: See rcs_parts["defaultPartPatterns"])
// @RETURN - A LIST of parts.
////
FUNCTION parts_rcs_get_rcs_parts {
  PARAMETER _ship IS SHIP.
  PARAMETER _patterns IS parts_rcs["defaultPartPatterns"].

  LOCAL pattern IS "".
  LOCAL part IS 0.
  LOCAL parts IS LIST().

  FOR pattern IN _patterns {
    LOCAL captured IS _ship:PARTSNAMEDPATTERN(pattern).
    FOR part IN captured {
      parts:ADD(part).
    }
  }
  RETURN parts.
}

////
// Get RCS modules from a list of preferably RCS parts.
// @PARAM _parts        - The parts to grab the modules from.
// @PARAM _module_names - A list of module names to look for. (Default: See parts_rcs["defaultModuleNames"])
// @RETURN - A LIST of the modules found.
////
FUNCTION parts_rcs_get_rcs_modules {
  PARAMETER _parts.
  PARAMETER _module_names IS parts_rcs["defaultModuleNames"].

  LOCAL part IS 0.
  LOCAL name IS "".
  LOCAL modules IS LIST().

  FOR part IN _parts {
    FOR name IN _module_names {
      IF part:HASMODULE(name) {
        modules:ADD(part:GETMODULE(name)).
      }
    }
  }
  RETURN modules.
}

////
// Store the current thrust limiter value for a group of RCS part modules.
// @PARAM _modules - The modules to store the value for.
// @RETURN - A LEXICON of PART:UID to thrust limiter value settings.
////
FUNCTION parts_rcs_store_thrust_limiter {
  PARAMETER _modules.

  LOCAL og_values IS LEXICON().

  FOR module IN _modules {
    IF module:HASFIELD("thrust limiter") {
      SET og_values[module:PART:UID] TO module:GETFIELD("thrust limiter").
    }
  }
  RETURN og_values.
}

////
// Restore previous thrust limiter values with a set of stored values.
// 5R4EWQ 21  1`  1`ewqZ@PARAM _modules       - The modules on which values are to be restored.
// @PARAM _stored_values - The stored values, see parts_rcs_store_thrust_limiter.
////
FUNCTION parts_rcs_restore_thrust_limiter {
  PARAMETER _modules.
  PARAMETER _stored_values.

  FOR module IN _modules {
    IF _stored_values:HASKEY(module:PART:UID) {
      IF module:HASFIELD("thrust limiter") {
        module:SETFIELD("thrust limiter", _stored_values[module:PART:UID]).
      }
    }
  }
}

////
// Set the thrust limiter value on a set of RCS thrusters.
// @PARAM modules - The modules to set the value on.
// @PARAM value   - The value to set.
////
FUNCTION parts_rcs_set_thrust_limiter {
  PARAMETER modules.
  PARAMETER value.

  FOR module IN modules {
    IF module:HASFIELD("thrust limiter") {
      module:SETFIELD("thrust limiter", value).
    }
  }
}

////
// Will this RCS thruster provide thrust in the FORE direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide FORE direction thrust.
////
FUNCTION parts_rcs_is_aligned_fore {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }

  IF NOT _thruster:FOREENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, _ship:FACING:FOREVECTOR).
}

////
// Will this RCS thruster provide thrust in the AFT direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide AFT direction thrust.
////
FUNCTION parts_rcs_is_aligned_aft {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }

  IF NOT _thruster:FOREENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, -(_ship:FACING:FOREVECTOR)).
}

////
// Will this RCS thruster provide thrust in the UP direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide UP direction thrust.
////
FUNCTION parts_rcs_is_aligned_up {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }
  
  IF NOT _thruster:TOPENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, _ship:FACING:UPVECTOR).
}

////
// Will this RCS thruster provide thrust in the DOWN direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide DOWN direction thrust.
////
FUNCTION parts_rcs_is_aligned_down {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }

  IF NOT _thruster:TOPENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, -(_ship:FACING:UPVECTOR)).
}

////
// Will this RCS thruster provide thrust in the STARBOARD direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide STARBOARD direction thrust.
////
FUNCTION parts_rcs_is_aligned_starboard {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }

  IF NOT _thruster:STARBOARDENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, _ship:FACING:STARVECTOR).
}

////
// Will this RCS thruster provide thrust in the PORT direction.
// @PARAM _thruster - The thruster to examine.
// @PARAM _ship     - The ship the thruster is attached to.
// @RETURN - True if this thruster will provide PORT direction thrust.
////
FUNCTION parts_rcs_is_aligned_port {
  PARAMETER _thruster.
  PARAMETER _ship IS SHIP.

  IF NOT _thruster:ISTYPE("RCS") {
    RETURN FALSE.
  }

  IF NOT _thruster:STARBOARDENABLED {
    RETURN FALSE.
  }

  RETURN parts_rcs_is_aligned(_thruster, -(_ship:FACING:STARVECTOR)).
}


////
// Internal API.
////
FUNCTION parts_rcs_is_aligned {
  PARAMETER _thruster.
  PARAMETER _vector.

  LOCAL aligned IS FALSE.
  LOCAL _v IS 0.

  FOR _v IN _thruster:THRUSTVECTORS {
    SET alignment TO _v * _vector.
    IF alignment > math:helper:rad:cos(45) {
      SET aligned TO TRUE.
    }
  }

  RETURN aligned.
}
