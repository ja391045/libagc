boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:debug, FALSE).
runstage:load().
SET max_runstage TO 6.

UNTIL runstage:stage > max_runstage {
  SET skipBump TO FALSE.
  PRINT "Runstage " + runstage:stage + ".".
	IF runstage:stage = 0 {
    PRINT "Doing launch.".
		launch:rocket:go(launch:rocket:default_profile, 100000, TRUE, 3, 5, staging:algorithm:flameOut, LIST(5)).
    LOCK STEERING TO PROGRADE.
    PRINT "Launch routine complete.".
	} ELSE IF runstage:stage = 1 {
    PRINT "Creating circulization manuever node.".
		SET newNode TO mnv:node:circularizeApoapsis().
    ADD newNode.
    PRINT "Node created.".
	} ELSE IF runstage:stage = 2 {
    PRINT "Executing circulization node.".
    UNLOCK STEERING.
		mnv:node:do(60, TRUE, 2).
    WAIT 1.
    REMOVE newNode.
    PRINT "Node execution complete.".
  } ELSE IF runstage:stage = 3 {
    // Test our shniz in a round-ish orbit.
    SET eta_a TO math:eta:periapsis().
    SET eta_b TO SHIP:ORBIT:ETA:PERIAPSIS.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.3) {
      PRINT "Testing ETA to Periapsis: Passed".
    } ELSE {
      PRINT "Testing ETA to Periapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_b TO SHIP:ORBIT:ETA:APOAPSIS.
    SET eta_a TO math:eta:apoapsis().
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.3) {
      PRINT "Testing ETA to Apoapsis: Passed".
    } ELSE {
      PRINT "Testing ETA to Apoapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_a TO math:eta:periToPeri().
    SET eta_b TO 0.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.05) {
      PRINT "Testing ETA from Periapsis to Periapsis: Passed".
    } ELSE {
      PRINT "Testing ETA from Periapsis to Periapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_a TO math:eta:periToApo().
    SET eta_b TO SHIP:ORBIT:PERIOD / 2.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.05) {
      PRINT "Testing ETA from Periapsis to Apoapsis: Passed".
    } ELSE {
      PRINT "Testing ETA from Periapsis to Apoapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
  } ELSE IF runstage:stage = 4 {
    // Punch out to a highly eccentric orbit.
    SET targetSMA TO ((SHIP:ORBIT:BODY:RADIUS * 2) + SHIP:ORBIT:PERIAPSIS + 750000) / 2.
    SET transferNode TO mnv:node:setApoAtPeri(targetSMA).
    ADD transferNode.
  } ELSE IF runstage:stage = 5 {
    mnv:node:do(30, TRUE, 2).
  } ELSE IF runstage:stage = 6 {
    // Test our shniz in a round-ish orbit.
    SET eta_a TO math:eta:periapsis().
    SET eta_b TO SHIP:ORBIT:ETA:PERIAPSIS.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.3) {
      PRINT "Testing ETA to Periapsis: Passed".
    } ELSE {
      PRINT "Testing ETA to Periapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_b TO SHIP:ORBIT:ETA:APOAPSIS.
    SET eta_a TO math:eta:apoapsis().
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.3) {
      PRINT "Testing ETA to Apoapsis: Passed".
    } ELSE {
      PRINT "Testing ETA to Apoapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_a TO math:eta:periToPeri().
    SET eta_b TO 0.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.05) {
      PRINT "Testing ETA from Periapsis to Periapsis: Passed".
    } ELSE {
      PRINT "Testing ETA from Periapsis to Periapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
    SET eta_a TO math:eta:periToApo().
    SET eta_b TO SHIP:ORBIT:PERIOD / 2.
    SET eta_diff TO ABS(eta_a - eta_b).
    IF math:helper:close(eta_a, eta_b, 0.05) {
      PRINT "Testing ETA from Periapsis to Apoapsis: Passed".
    } ELSE {
      PRINT "Testing ETA from Periapsis to Apoapsis: Failed.".
      PRINT "My ETA: " + eta_a + ", kOS ETA: " + eta_b + " differs by " + eta_diff.
      SET skipBump TO TRUE.
    }
  }
  syslog:upload().
  IF NOT skipBump {
    runstage:bump().
  }
  runstage:preserve().
  IF skipBump { BREAK. }.
}
syslog:shutdown().