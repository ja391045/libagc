////
// library for dealing with engine parts.
////

GLOBAL _engines IS LEXICON(
  "findByNameAndStage", parts_engine_find_by_name_and_stage@,
  "lockGimbal", parts_engine_lock_gimbal@,
  "unlockGimbal", parts_engine_unlock_gimbal@,
  "shutdown", parts_engine_shutdown@,
  "activate", parts_engine_activate@,
  "swapMode", parts_engine_swap_mode@
).

////
// Switch mode on the given engines.
// @PARAM eng - The engines to operate over.
////
FUNCTION parts_engine_swap_mode {
  PARAMETER eng.
  LOCAL _e IS 0.
  FOR _e IN eng {
    IF _e:IGNITION AND _e:MULTIMODE {
      _e:TOGGLEMODE().
    }
  }
}

////
// Find engines by name in stages <= the stage provided.
// @PARAM name - The name of the engine to find (Default: stage:number).
// @PARAM _stage - The stage(s) to look for.
// @RETURN - A list of engines, and empty list if none found.
////
FUNCTION parts_engine_find_by_name_and_stage {
  PARAMETER name.
  PARAMETER _stage IS STAGE:NUMBER.

  LOCAL _eng IS 0.
  LOCAL _engFound IS LIST().
  FOR _eng IN SHIP:ENGINES {
    IF _eng:NAME = name AND _eng:STAGE >= _stage { 
      _engFound:ADD(_eng).
    }
  }
  RETURN _engFound.
}

////
// Lock the gimbals of the given engines.
// @PARAM - eng - A List of engine parts.
////
FUNCTION parts_engine_lock_gimbal {
  PARAMETER eng.
  LOCAL _e IS 0.
  FOR _e IN eng {
    IF _e:HASGIMBAL {
      SET _e:GIMBAL:LOCK TO TRUE.
    }
  }
}

////
// Lock the gimbals of the given engines.
// @PARAM - eng - A List of engine parts.
////
FUNCTION parts_engine_unlock_gimbal {
  PARAMETER eng.
  LOCAL _e IS 0.
  FOR _e IN eng {
    IF _e:HASGIMBAL {
      SET _e:GIMBAL:LOCK TO FALSE.
    }
  }
}

////
// Shutdown the given engines.
// @PARAM - eng - A List of engine parts.
////
FUNCTION parts_engine_shutdown {
  PARAMETER eng.
  LOCAL _e IS 0.
  FOR _e IN eng {
    IF _e:IGNITION {
      _e:SHUTDOWN().
    }
  }
}

////
// Startup the given engines.
// @PARAM - eng - A List of engine parts.
////
FUNCTION parts_engine_activate {
  PARAMETER eng.
  LOCAL _e IS 0.
  FOR _e IN eng {
    IF NOT _e:IGNITION {
      _e:ACTIVATE().
    }
  }
}
