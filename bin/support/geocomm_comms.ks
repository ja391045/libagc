boot:require("comms").

GLOBAL ant_cache IS LIST().
GLOBAL team IS LIST("Kerbin Geocomm 2", "Kerbin Geocomm 3").
GLOBAL team_mnv_time IS LEXICON().
GLOBAL antenna_out_rc IS LIST().
GLOBAL mnv_ready IS LEXICON().
GLOBAL mnv_time IS -1.

////
// team leader functions
////
FUNCTION lead_set_antennas {
  LOCAL antenna_modules IS cache_ant_modules().
  LOCAL all_tgt IS FALSE.

  LIST TARGETS IN all_tgt.

  FOR member IN team {

    // Make sure all the members have launched, met-up in orbit, and are station keeping.
    // If a member doesn't exist, and we try to create a VESSEL out of it, the script will
    // fail.  We must compare strings.  all_tgt:FIND will not work.
    LOCAL have_member IS FALSE.
    FOR tgt IN all_tgt {
      IF tgt:NAME = member {
        SET have_member TO TRUE.
        BREAK.
      }
    }

    IF NOT have_member {
      syslog:msg("Cannot find member [" + member + "], holding off on antenna request.", syslog:level:info, "mission:bin:lead_set_antennas").
      RETURN FALSE.
    }

    LOCAL vsl IS VESSEL(member).
    IF vsl:DISTANCE > 10000 {
      syslog:msg("Member [" + member + "] exists, but is not close enough, holding off on antenna request.", syslog:level:info, "mission:bin:lead_set_antennas").
      RETURN FALSE.
    }
  }
  // If we are here, all team members are present and accounted for.
  LOCAL headers IS LEXICON("re", "request_antenna").
  FOR member IN team {
    LOCAL other_members IS team:COPY.
    other_members:REMOVE(other_members:FIND(member)).
    ant_to_target(member).
    LOCAL payload IS LEXICON("action", "activate_antenna", "target", SHIP:NAME).
    LOCAL ant_to_lead IS std:struct:message:new(headers, payload).
    comms:vessel:send(ant_to_lead, member).
    FOR peer IN other_members {
      LOCAL payload IS LEXICON("action", "activate_antenna", "target", peer).
      LOCAL ant_to_peer IS std:struct:message:new(headers, payload).
      comms:vessel:send(ant_to_peer, member).
    }
  }
  RETURN TRUE.
}

FUNCTION lead_set_manuevers {
  IF mnv_time < 0 {
    IF VOLUME(1):EXISTS("/tmp/mnv_time.dat") {
      SET mnv_time TO VOLUME(1):OPEN("/tmp/mnv_time.dat"):READALL:STRING:TONUMBER.
    } ELSE {
      SET mnv_time TO TIME:SECONDS + SHIP:ORBIT:ETA:APOAPSIS + SHIP:ORBIT:PERIOD.
      VOLUME(1):CREATE("/tmp/mnv_time.dat").
      LOCAL fd IS VOLUME(1):OPEN("/tmp/mnv_time.dat").
      fd:CLEAR().
      fd:WRITE(mnv_time:TOSTRING).
    }
    LOCAL base IS mnv_time.
    FOR member IN team {
      SET base to base + SHIP:ORBIT:PERIOD.
      SET team_mnv_time[member] TO base.
    }
  }

  FOR member IN team {
    IF std:isValidTarget(member) {
      IF NOT mnv_ready:HASKEY(member) OR NOT mnv_ready[member] {
        LOCAL vsl IS VESSEL(member).
        IF vsl:DISTANCE < 10000 {
          LOCAL headers IS LEXICON("re", "circ_node").
          LOCAL payload IS LEXICON("mnv_time", team_mnv_time[member]).
          LOCAL message IS std:struct:message:new(headers, payload).
          comms:vessel:send(message, member).
        } ELSE {
          syslog:msg("Member [" + member + "] exists, but is not close enough, holding off on mnv request.", syslog:level:info, "mission:bin:lead_set_manuevers").
        }
      } ELSE {
        syslog:msg("Member [" + member + "] is ready for manuever, skipping.", syslog:level:info, "mission:bin:lead_set_manuevers").
      }
    } ELSE {
      syslog:msg("Cannot find member [" + member + "], holding off on mnv request.", syslog:level:info, "mission:bin:lead_set_manuevers").
    }
  }

  LOCAL rdy IS TRUE.
  FOR member IN team {
    IF NOT mnv_ready:HASKEY(member) OR NOT mnv_ready[member] {
      syslog:msg("Do not have confirmation from [" + member + "].  Not yet ready.", syslog:level:warn, "misison:bin:lead_set_manuevers").
      SET rdy TO FALSE.
    }
  }
  RETURN rdy.
}

FUNCTION lead_set_my_mnv {
  // If we are here then all members are present and accounted for.
  // We need to get a little fancy with our node, basically if we have any
  // manuever nodes set, we want to remove them, then re-add the correct one.
  IF mnv_time < 0 {
    IF VOLUME(1):EXISTS("/tmp/mnv_time.dat") {
      SET mnv_time TO VOLUME(1):OPEN("/tmp/mnv_time.dat"):READALL:STRING:TONUMBER.
    } ELSE {
      SET mnv_time TO TIME:SECONDS + SHIP:ORBIT:ETA:APOAPSIS + SHIP:ORBIT:PERIOD.
      VOLUME(1):CREATE("/tmp/mnv_time.dat").
      LOCAL fd IS VOLUME(1):OPEN("/tmp/mnv_time.dat").
      fd:CLEAR().
      fd:WRITE(mnv_time:TOSTRING).
    }
  }
  FOR node IN ALLNODES {
    REMOVE node.
  }
  LOCAL lead_node IS mnv:node:circularizeApoapsis().
  SET lead_node:TIME TO mnv_time.
  ADD lead_node.
}

FUNCTION request_antenna_callback {
  PARAMETER _success.
  PARAMETER _rc_code.
  PARAMETER _message.

  LOCAL item IS LIST(_success, _rc_code).
  antenna_out_rc:ADD(item).
  RETURN TRUE.
}

FUNCTION team_mnv_ready_delegate {
  PARAMETER _message.
  
  syslog:msg("Response from member [" + _message["headers"]["sender"] + "] is [" + _message["payload"]["ready"] + "].", syslog:level:debug, "<team_mnv_ready_delegate>").
  SET mnv_ready[_message["headers"]["sender"]] TO _message["payload"]["ready"].
}

FUNCTION lead_register_callbacks {
  comms:vessel:addCallback("antenna", antenna_msg_matcher@, request_antenna_callback@).
}

FUNCTION lead_register_delegates {
  comms:vessel:addDelegate("mnv_ready", mnv_msg_ready_matcher@, team_mnv_ready_delegate@).
}
  
////
// Team member functions.
////
FUNCTION request_antenna_delegate {
  PARAMETER _message.

  ant_to_target(_message["payload"]["target"]).
}

FUNCTION request_mnv_delegate {
  PARAMETER _message.

  // We can't manipulate manuever nodes unless we are the active vessel.
  // So we'll store the node time then ack back that we received it.  Next time
  // this ship is activeVessel, we'll add the node if we don't have it already.

  IF NOT VOLUME(1):EXISTS("/tmp/mnv_time.dat") {
    VOLUME(1):CREATE("/tmp/mnv_time.dat").
    LOCAL fd IS VOLUME(1):OPEN("/tmp/mnv_time.dat").
    fd:CLEAR().
    SET mnv_time TO _message["payload"]["mnv_time"].
    fd:WRITE(mnv_time:TOSTRING).
  }
  // Send back a message received.
  LOCAL headers IS LEXICON("re", "circ_node_ready").
  LOCAL payload IS LEXICON("ready", TRUE).
  LOCAL reply IS std:struct:message:new(headers, payload).
  comms:vessel:send(reply, _message["headers"]["sender"]).
}

// Must be active vessel to do this.
FUNCTION make_node {
  IF NOT std:activeVessel() { RETURN FALSE. }
  IF mnv_time < 0 {
    syslog:msg("Do not have valid time.", syslog:level:warn, "mission:bin:make_node").
    IF NOT VOLUME(1):EXISTS("/tmp/mnv_time.dat") { 
      syslog:msg("Do not have record of manuever time.", syslog:level:warn, "mission:bin:make_node").
      RETURN FALSE. 
    }
    SET mnv_time TO VOLUME(1):OPEN("/tmp/mnv_time.dat"):READALL:STRING:TONUMBER.
  }
  IF mnv_time < 0 { 
    syslog:msg("Even after reading in time, mnv time is still invalid.", syslog:level:warn, "mission:bin:make_node").
    RETURN FALSE. 
  }
  FOR _n IN ALLNODES {
    REMOVE _n.
  }
  LOCAL follow_node IS mnv:node:circularizeApoapsis().
  SET follow_node:TIME TO mnv_time.
  ADD follow_node.
  RETURN TRUE.
}
  
FUNCTION team_register_delegates {
  comms:vessel:addDelegate("antenna", antenna_msg_matcher@, request_antenna_delegate@).
  comms:vessel:addDelegate("manuever", mnv_msg_matcher@, request_mnv_delegate@).
}

FUNCTION team_unregister_antenna {
  comms:vessel:removeDelegate("antenna").
}

FUNCTION team_unregister_mnv {
  comms:vessel:removeDelegate("manuever").
}

////
// Functions for both leader and members.
////
FUNCTION ant_to_target {
  PARAMETER _tgt_name.

  LOCAL ants IS cache_ant_modules().

  // If we already have an active antenna pointed at this target, then we don't need to do
  // anything.
  FOR ant_mod IN ants {
    IF ant_mod:GETFIELD("status") <> "Off" AND ant_mod:GETFIELD("target") = _tgt_name {
      RETURN 0.
    }
  }

  // Find an antenna that isn't being used and point it at the target.
  FOR ant_mod IN ants {
    IF ant_mod:GETFIELD("status") = "Off" {
      ant_mod:DOACTION("activate", TRUE).
      ant_mod:SETFIELD("target", _tgt_name).
      RETURN 1.
    }
  }

  // We don't have any inactive antennas left.
  RETURN -1.
}

FUNCTION antenna_msg_matcher {
  PARAMETER _headers.

  RETURN _headers:HASKEY("re") AND _headers["re"] = "request_antenna".
}

FUNCTION mnv_msg_matcher {
  PARAMETER _headers.

  RETURN _headers:HASKEY("re") AND _headers["re"] = "circ_node".
}

FUNCTION mnv_msg_ready_matcher {
  PARAMETER _headers.

  RETURN _headers:HASKEY("re") AND _headers["re"] = "circ_node_ready".
}

// lookup parts when we need to access them.
FUNCTION cache_ant_modules {
  IF ant_cache:EMPTY {
    LOCAL ant_parts IS SHIP:PARTSNAMEDPATTERN("^HighGainAntenna5.*$").
    FOR ant_part IN ant_parts {
      IF ant_part:HASMODULE("ModuleRTAntenna") {
        ant_cache:add(ant_part:GETMODULE("ModuleRTAntenna")).
      }
    }
  }
  return ant_cache:COPY.
}
