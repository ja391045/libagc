boot:require("runstage").
boot:require("launch").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:trace, FALSE, PATH("0:/log/" + SHIP:NAME + ".log"), FALSE).
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
		mnv:node:do(60, TRUE, TRUE, 2).
    WAIT 1.
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

    WAIT 1.
    SET orbitTime TO math:kepler:elapsedTime(0, 90).
    SET eta_pa TO SHIP:ORBIT:ETA:PERIAPSIS.
    IF eta_pa > 90 {
      KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + eta_pa - 30).
      WAIT 2.
    }
    WAIT UNTIL math:helper:close(SHIP:ORBIT:TRUEANOMALY, 0, 0.1).
    SET clock TO TIME:SECONDS.
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + orbitTime - 30).
    WAIT 2.

    WAIT UNTIL math:helper:close(SHIP:ORBIT:TRUEANOMALY, 90, 0.1).
    SET clock TO TIME:SECONDS - clock.
    IF math:helper:close(orbitTime, clock, 1) {
      PRINT "Testing elapsed time between true anomalies: Passed".
    } ELSE {
      PRINT "Testing elapsed time between true anomalies: Failed.".
      PRINT "True anomaly 0-90 degrees expected " + orbitTime + " seconds but took " + clock + " seconds.".
      SET skipBump TO TRUE.
    }
    WAIT 1.

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:ETA:APOAPSIS, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND math:helper:close(ta_at, 180, 0.1) {
      PRINT "Testing true anomaly at specified time period: Passed".
    } ELSE {
      PRINT "Testing true anomaly at specified time period: Failed.".
      PRINT "Expected 180 degrees true anomaly at ETA apoapsis, but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
      SET skipBump TO TRUE.
    }

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:PERIOD + SHIP:ORBIT:ETA:APOAPSIS, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND math:helper:close(ta_at, 540, 0.1) {
      PRINT "Testing true anomaly at specified time greater than orbit period: Passed".
    } ELSE {
      PRINT "Testing true anomaly at specified time greater than orbit period: Failed.".
      PRINT "Expected 540 degrees to Apoapsis, but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
      SET skipBump TO TRUE.
    }

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS - SHIP:ORBIT:PERIOD, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND (math:helper:close(ta_at, 0, 0.1) OR math:helper:close(ta_at, 360, 0.1)) {
      PRINT "Testing true anomaly at specified time in the past: Passed.".
    } ELSE {
      PRINT "Testing true anomaly at specified time in the past: Failed.".
      PRINT "Expected 0 degrees to Periapsis but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
      SET skipBump TO TRUE.
    }
  } ELSE IF runstage:stage = 4 {
    // Punch out to a highly eccentric orbit.
    SET targetSMA TO ((SHIP:ORBIT:BODY:RADIUS * 2) + SHIP:ORBIT:PERIAPSIS + 750000) / 2.
    SET transferNode TO mnv:node:setApoAtPeri(targetSMA).
    ADD transferNode.
    WAIT 1.
  } ELSE IF runstage:stage = 5 {
    mnv:node:do(30, TRUE, TRUE, 2).
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

    WAIT 3.
    SET orbitTime TO math:kepler:elapsedTime(0, 90).
    SET eta_pa TO SHIP:ORBIT:ETA:PERIAPSIS.
    IF eta_pa > 90 {
      KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + eta_pa - 30).
      WAIT 3.
    }
    WAIT UNTIL math:helper:close(SHIP:ORBIT:TRUEANOMALY, 0, 0.01).
    SET clock TO TIME:SECONDS.
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + orbitTime - 30).
    WAIT 3.

    WAIT UNTIL math:helper:close(SHIP:ORBIT:TRUEANOMALY, 90, 0.01).
    SET clock TO TIME:SECONDS - clock.
    IF math:helper:close(orbitTime, clock, 1.5) {
      PRINT "Testing elapsed time between true anomalies: Passed".
    } ELSE {
      PRINT "Testing elapsed time between true anomalies: Failed.".
      PRINT "True anomaly 0-90 degrees expected " + orbitTime + " seconds but took " + clock + " seconds.".
      SET skipBump TO TRUE.
    }
    WAIT 1.

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:ETA:APOAPSIS, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND math:helper:close(ta_at, 180, 0.1) {
      PRINT "Testing true anomaly at specified time period: Passed".
    } ELSE {
      PRINT "Testing true anomaly at specified time period: Failed.".
      PRINT "Expected 180 degrees true anomaly at ETA apoapsis, but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
      SET skipBump TO TRUE.
    }

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:PERIOD + SHIP:ORBIT:ETA:APOAPSIS, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND math:helper:close(ta_at, 540, 0.1) {
      PRINT "Testing true anomaly at specified time greater than orbit period: Passed".
    } ELSE {
      PRINT "Testing true anomaly at specified time greater than orbit period: Failed.".
      PRINT "Expected 540 degrees to Apoapsis, but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
      SET skipBump TO TRUE.
    }

    SET ta_at TO math:kepler:trueAnomalyAt(TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS - SHIP:ORBIT:PERIOD, SHIP:ORBIT, 0.1).
    IF ta_at:ISTYPE("Scalar") AND (math:helper:close(ta_at, 0, 0.1) OR math:helper:close(ta_at, 360, 0.1)) {
      PRINT "Testing true anomaly at specified time in the past: Passed.".
    } ELSE {
      PRINT "Testing true anomaly at specified time in the past: Failed.".
      PRINT "Expected 0 degrees to Periapsis but got " + ta_at + ".".
      IF ta_at:HASSUFFIX("error") {
        PRINT "Error returned from Newton-Raphson:  " + ta_at:error + ".".
      }
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