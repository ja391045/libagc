////
// library for maneuver nodes.
////

boot:require("math").
boot:require("telemetry").
boot:require("staging").
boot:require("syslog").

GLOBAL mnv_node is LEXICON(
  "do",                   mnv_node_do@,
  "circularizeApoapsis",  mnv_node_circularize_apoapsis@,
  "circularizePeriapsis", mnv_node_circularize_periapsis@,
  "setApoAtPeri",         mnv_node_set_apo_at_peri@,
  "setPeriAtApo",         mnv_node_set_peri_at_apo@
).

////
// Execute a manuever node.
////
FUNCTION mnv_node_do {
  PARAMETER align_time IS 60.
  PARAMETER autostage IS TRUE.
  PARAMETER stageUntil IS 0.
  PARAMETER allowRCS IS TRUE.
  PARAMETER autostage_algorithm IS staging:algorithm:flameOut.

  LOCAL oldSAS IS SAS.
  LOCAL oldRCS IS RCS.
  LOCAL nd IS NEXTNODE.
  LOCAL nd_ts IS TIMESTAMP(nd:TIME).
  LOCAL fuel_mass IS ROUND(telemetry:tsiolkovsky:fuelMass(nd:DELTAV:MAG),3).
  LOCAL final_mass IS ROUND(SHIP:MASS - fuel_mass, 3).
  LOCAL min_acc IS telemetry:performance:availableAccel().
  LOCAL max_acc IS telemetry:performance:accelAtMass(final_mass).
  LOCAL avg_acc IS ROUND((max_acc + min_acc) / 2, 3).
  LOCAL burn_tm IS nd:DELTAV:MAG / avg_acc.
  LOCAL offset_tm IS (burn_tm / 2) + align_time.
  LOCAL tset IS 0.
  LOCAL done IS FALSE.
  LOCAL nd_og_dv IS nd:DELTAV.
  LOCAL acc_lock IS FALSE.
  LOCAL accel_info IS LEXICON(
    "min_acc", min_acc,
    "max_acc", max_acc,
    "avg_acc", avg_acc,
    "burn_tm", burn_tm
  ).
  LOCAL acc_msg_fmt IS "Minimum acceleration: ${min_acc}, Maximum Acceleration: ${max_acc}, Average Acceleration: ${avg_acc}, Burn Time: ${burn_tm}".

  LOCAL msg IS std:string:sprintf(acc_msg_fmt, accel_info).
  syslog:msg("Building offset. " + msg, syslog:level:debug, "mnv:node:do").
  syslog:msg("Executing node " + nd_ts:FULL + ".  It will require " + ROUND(nd:DELTAV:MAG) + "m/s.", syslog:level:info, "mnv:node:do").
  syslog:msg("Node burn time is " + burn_tm + " s.  Offset is " + offset_tm + " s.", syslog:level:debug, "mnv:node:do").
  syslog:msg("Waiting " + (nd:ETA - offset_tm) + "s for alignment phase.", syslog:level:info, "mnv:node:do").

  SET SAS TO FALSE.
  SET RCS TO allowRCS.

  // IF mcp ever works, get steering lock.
  LOCK STEERING TO nd:DELTAV.
  syslog:msg("Aligning.", syslog:level:info, "mnv:node:do").
  WAIT UNTIL math:helper:close(VANG(nd_og_dv, SHIP:FACING:VECTOR), 0, 0.25).

  syslog:msg("Alignment complete.",  syslog:level:info, "mnv:node:do").

  if autostage {
    syslog:msg("Starting autostage.", syslog:level:debug, "mnv:node:do").
    staging:auto(stageUntil, autostage_algorithm, FALSE).
  }

  syslog:msg("Waiting " + ROUND((nd:ETA - burn_tm / 2), 1) + "s for burn start.", syslog:level:info, "mnv_node_do").
  WAIT UNTIL nd:ETA <= (burn_tm / 2).

  LOCK THROTTLE TO tset.
  LOCK acc_lock TO telemetry:performance:availableAccel().

  // Once we are close to meeting the DV requirement, lock steering to a 
  // copy that isn't going to move around.
  WHEN nd:DELTAV:MAG < 5 THEN {
    SET nd_og_dv TO nd:DELTAV.
    LOCK STEERING TO nd_og_dv.
    RETURN FALSE.
  }
  UNTIL done {
   SET tset to MIN(nd:DELTAV:MAG/acc_lock, 1).
   // If we've overshot at all, bail immediately.
   IF VDOT(nd_og_dv, nd:DELTAV) < 0 {
     LOCK throttle TO 0.
     break.
   }
   // We still have a tiny bit to burn.
   IF nd:DELTAV:MAG <= 0.1 {
    WAIT UNTIL VDOT(nd_og_dv, nd:DELTAV) < 0.5.
    LOCK THROTTLE TO 0.
    SET tset TO 0.
    SET done TO TRUE.
   }
  }
  syslog:msg("Stopping autostage.", syslog:level:debug, "staging:auto").
  staging:stop().
  UNLOCK acc_lock.
  UNLOCK STEERING.
  UNLOCK THROTTLE.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
  SET SAS TO oldSAS.
  SET RCS TO oldRCS.
  syslog:msg("Node complete, remaining DV is: " + ROUND(nd:DELTAV:MAG, 2)+ "m/s", syslog:level:info, "mnv_node_do").
  REMOVE nd.
}

////
// Create a new manuever node to circularize your orbit at apoapsis.
// @PARAM _obt - The orbit to operate on.  (Default: SHIP:ORBIT).
// @RETURN - The created node.
////
FUNCTION mnv_node_circularize_apoapsis {
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL targetSMA IS _obt:BODY:RADIUS + _obt:APOAPSIS.
  RETURN mnv_node_set_peri_at_apo(targetSMA, _obt).
}

////
// Create a new manuever node to circualarize your orbit at periapsis.
// @PARAM _obt - The orbit to operate on.  (Default: SHIP:ORBIT).
// @RETURN - The created node.
////
FUNCTION mnv_node_circularize_periapsis {
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL targetSMA IS _obt:BODY:RADIUS + _obt:PERIAPSIS.
  RETURN mnv_node_set_apo_at_peri(targetSMA, _obt).
}

////
// Modify orbital altitude starting at a given time.
// @PARAM utm - The universal time to undertake the burn.
// @PARAM alt - The new altitude of the orbit.
// @PARAM _obt - The orbit or patch for this burn.
////
FUNCTION mnv_node_mod_alt_at {
  PARAMETER utm.
  PARAMETER _alt.
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL targetRadius IS _obt:BODY:RADIUS + _alt.
  LOCAL targetSMA IS targetRadius.
}



////
// Raise the pariapsis point of an orbit by burning at the apoapsis point.
// @PARAM targetSMA - The semi-major axist of the new orbit.
// @PARAM _obt - The orbit to operate on. (Default: SHIP:ORBIT)
// @RETURN - The newly created node.
////
FUNCTION mnv_node_set_apo_at_peri {
  PARAMETER targetSMA.
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL start_r IS _obt:PERIAPSIS + _obt:BODY:RADIUS.
  LOCAL dv IS math:kepler:orbit:visViva(targetSMA, start_r, _obt:SEMIMAJORAXIS, _obt:BODY:MU).
  syslog:msg(
    "Setting Apoapsis to " + ROUND(start_r) + " with SMA of " + ROUND(targetSMA) + " at Periapsis requires " + ROUND(dv, 2) + "m/s.",
    syslog:level:info,
    "mnv:node:setApoAtPeri"
  ).
  LOCAL nn IS NODE(TIME:SECONDS + _obt:ETA:PERIAPSIS, 0, 0, dv).
  RETURN nn.
}

////
// Raise the apoapsis point of an orbit by burning at the periapsis point.
// @PARAM targetSMA - The semi-major axist of the new orbit.
// @PARAM _obt - The orbit to operate on. (Default: SHIP:ORBIT)
// @RETURN - The newly created node.
////
FUNCTION mnv_node_set_peri_at_apo {
  PARAMETER targetSMA.
  PARAMETER _obt IS SHIP:ORBIT.

  LOCAL start_r IS _obt:APOAPSIS + _obt:BODY:RADIUS.
  LOCAL dv IS math:kepler:orbit:visViva(targetSMA, start_r, _obt:SEMIMAJORAXIS, _obt:BODY:MU). 
  syslog:msg(
    "Setting Periapsis to " + ROUND(start_r) + " with SMA of " + ROUND(targetSMA) + " at Apoapsis requires " + ROUND(dv,2) + "m/s.",
    syslog:level:info,
    "mnv:node:setPeriAtApo"
  ).
  LOCAL nn IS NODE(TIME:SECONDS + _obt:ETA:APOAPSIS, 0, 0, dv).
  RETURN nn.
}
