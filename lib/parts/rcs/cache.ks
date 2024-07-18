////
// Build and maintain a cache of RCS thrusters so the ship doesn't need to be
// queried over and over.  Try to lazy init the cache as much as possible.
////

GLOBAL parts_rcs_cache IS LEXICON(
  "thrustModuleNames", LIST("ModuleRCSFX"),
  "__cache__",         LIST(),
  "__mcache__",        LIST(),
  "__expired__",       TRUE,
  "thrusters",         parts_rcs_cache_thrusters@,
  "modules",           parts_rcs_cache_modules@,
  "expire",            parts_rcs_cache_expire@
).

////
// Fetch all the rcs thrusters on the current vessel.  This function will lazily cache the results.
// See parts_rcs_cache_expire to refresh the cache.
// @RETURN - A LIST of all RCS parts on this vessel.
////
FUNCTION parts_rcs_cache_thrusters {
  IF parts_rcs_cache["__expired__"] {
    LIST RCS IN parts_rcs_cache["__cache__"].
  }
  RETURN parts_rcs_cache["__cache__"].
}

////
// Fetch the RCS thruster modules (i.e. the module that sets thrust limiter) for the given RCS parts.
// This function will cache results so it doesn't have to be looked up again on subsequent calls.  See
// parts_rcs_cache_expire to reset this cache.  Note there could be more than one module depending on which
// mods have been installed.  Modify parts_rcs_cache["thrustModuleNames"] with the bin/missions executable as
// required.
// @PARAM _rcs_parts - The LIST of parts to fetch the modules for. (Default: LIST()).
// @RETURN - A LEXICON of PART:UID to LIST(PARTMODULE, PARTMODULE) mapping.
////
FUNCTION parts_rcs_cache_thruster_modules {
  PARAMETER _rcs_parts IS LIST().

  LOCAL mods IS LEXICON().
  FOR _p IN _rcs_parts {
    IF NOT parts_rcs_cache["__mache__"]:HASKEY(_p:UID) {
      LOCAL _pmods IS LIST().
      FOR name IN parts_rcs_cache["thrustModuleNames"] {
        IF _p:HASMODULE(name) {
          _pmods:ADD(_p:GETMODULE(name)).
      }
      SET parts_rcs_cache["__mcache__"][_p:UID] TO _pmods.
    }
    SET mods[_p:UID] TO parts_rcs_cache["__mcache__"][_p:UID].
  }
}

////
// Call to force the cached RCS PART and PARTMODULE information to expire.  For instance after staging or after docking/undocking.
////
FUNCTION parts_rcs_cache_expire {
  SET parts_rcs_cache["__expired__"] TO TRUE.
  parts_rcs_cache["__mcache__"]:CLEAR().
}
