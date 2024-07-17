////
// Library to snapshot the status of certain complex elements.
////
boot:require("syslog").

GLOBAL telemetry_status IS LEXICON(
    "resourceByStage", telemetry_status_resource_by_stage@,
    "dryMassForStage", telemetry_status_dry_mass_for_stage@,
    "massAtStage",     telemetry_status_mass_at_stage@
).


////
// Calculate the total delta-v present in a given stage.  This may not work correctly for weird setups with
// crossfeed decoupler, fuel hoses, like asparagus staging.  It may need further refinement.
// @PARAM _ship  - The ship to examine. (Default: SHIP).
// @PARAM _filter - A list of engine name to filter out of the results (Default: LIST("sepMotor1"))
// @RETURN - The cumulative delta-v in all stages.
////
FUNCTION telmetry_status_delta_v_for_stage {
  PARAMETER _stage IS SHIP:STAGENUM.
  PARAMETER _ship IS SHIP.
  PARAMETER _filter IS LIST("sepMotor1").

  LOCAL dv IS 0.
  // TODO:  finish this up.

}

////
// The mass of a vessel once staged down to _stage.
// @PARAM _ship  - The ship to examine. (Default: SHIP).
// @PARAM _stage - The stage number to examine. (Default: SHIP:STAGENUM - 1).
// @RETURN - The calculated mass of the stage.
////
FUNCTION telemetry_status_mass_at_stage {
  PARAMETER _ship IS SHIP.
  PARAMETER _stage IS SHIP:STAGENUM - 1.

  // A stag >= SHIP:STAGENUM doesn't change the ship's mass.
  IF _stage < 0 OR _stage >= SHIP:STAGENUM {
    RETURN SHIP:MASS.
  }

  IF _stage < 0 {
    SET _stage TO 0.
  }

  LOCAL all_parts IS 0.
  LOCAL sm IS SHIP:MASS.
  LOCAL part IS FALSE.

  LIST PARTS in all_parts.
  FOR part IN PARTS {
    IF part:STAGE > _stage {
      SET sm TO sm - part:MASS.
    }
  }
  RETURN sm.
}

////
// Get the dry mass for a given stage.
// @PARAM - stage - The stage number for which the drymass should be obtained.
// @RETURN - The dry mass of the given stage in metric tons.
////
FUNCTION telemetry_status_dry_mass_for_stage {
    PARAMETER _stage IS STAGE:NUMBER.

    LOCAL all_parts IS 0.
    LOCAL _mass IS 0.

    LIST PARTS IN all_parts.
    FOR part IN all_parts {
        IF part:STAGE = _stage {
            SET _mass TO _mass + part:DRYMASS.
        }
    }

    RETURN _mass.
}

////
// Get the resources available broken down per stage.
// @PARAM - include - An inclusive filter list of resource names.  If the list is empty, all
//                    resources will be included.
// @PARAM - maxStage - Only include resources down to this stage.  Any resources attached to stages
//                     less than this will be excluded. For all stages, use -1 which is the default.
// @RETURN - Lexicon - A hash of resources keyed by stage.
////
FUNCTION telemetry_status_resource_by_stage {
  PARAMETER include IS LIST().
  PARAMETER maxStage IS STAGE:NUMBER.
  LOCAL res_by_stage IS LEXICON().
  LOCAL all_parts IS 0.

  LIST PARTS IN all_parts.

  FOR _part IN all_parts {
    IF _part:STAGE >= maxStage AND _part:RESOURCES:LENGTH > 0 {
      LOCAL this_stage IS _part:STAGE.

      IF NOT res_by_stage:HASKEY(this_stage) {
        res_by_stage:ADD(this_stage, LEXICON()).
      }
      
      FOR _res IN _part:RESOURCES {
        LOCAL this_res IS _res:NAME.

        IF include:FIND(this_res) >= 0 OR include:EMPTY() {
            IF NOT res_by_stage[this_stage]:HASKEY(this_res) {
             res_by_stage[this_stage]:ADD(this_res, LEXICON()).
            }

            LOCAL res IS _telemetry_status_res_snip(this_res, _res:CAPACITY, _res:AMOUNT, res_by_stage[this_stage][this_res]).
            SET res_by_stage[this_stage][this_res] TO res.
        }
      }
    }
  }
  RETURN res_by_stage.
}


////
// API: Internal
// Create or add to a resource snippet.
////
FUNCTION _telemetry_status_res_snip {
  PARAMETER name.
  PARAMETER capacity.
  PARAMETER amount.
  PARAMETER snippet IS LEXICON().

  IF NOT snippet:HASKEY("name") {
    snippet:ADD("name", name).
  }

  IF snippet:HASKEY("capacity") {
    SET snippet["capacity"] TO snippet["capacity"] + capacity.
  } ELSE {
    snippet:ADD("capacity", capacity).
  }

  IF snippet:HASKEY("amount") {
    SET snippet["amount"] TO snippet["amount"] + amount.
  } ELSE {
    snippet:ADD("amount", amount).
  }

  RETURN snippet.
}
