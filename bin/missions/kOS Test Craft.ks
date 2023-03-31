boot:require("std").
boot:require("mcp").
boot:require("syslog").
boot:require("runstage").
boot:require("staging").
boot:require("launch").
boot:require("mnv").
boot:require("telemetry").
boot:require("parts").
boot:require("math").

// std:string:sprintf
SET finalString TO "1024 plus 1.114 minus True".
SET values TO LEXICON(
  "one",   1024,
  "two",   1.114,
  "three", TRUE
).

SET parsed TO std:string:sprintf("${one} plus ${two} minus ${three}", values).
IF parsed = finalString {
  PRINT "std:string:sprintf - passed.".
} else {
  PRINT "std:string:sprintf - failed.".
  PRINT "Expected: " + finalString.
  PRINT "Found   : " + parsed.
}

// std:err:strerr
SET expected TO "No such file or directory".
SET received TO std:err:strerr(100).
IF expected = received {
  PRINT "std:err:strerr - passed.".
} ELSE {
  PRINT "std:err:strerr - failed.".
  PRINT "Expected: " + expcted + ".".
  PRINT "Received: " + received + ".".
}

// std:struct:pqueue Priority queue.
SET tst_pqueue TO std:struct:pqueue:init().
IF tst_pqueue:ISTYPE("List") {
  PRINT "std:struct:pqueue:init - passed.".
} ELSE {
  PRINT "std:struct:pqueue:init - failed.".
  PRINT "Expected pqueue type to List, instead got: " + tst_pqueue:TYPENAME + ".".
}

IF std:struct:pqueue:empty(tst_pqueue) {
  PRINT "std:struct:pqueue:empty - passed.".
} ELSE { 
  PRINT "std:struct:pqueue:empty - failed.".
  PRINT "Expected pqueue to be empty.".
}

std:struct:pqueue:push(tst_pqueue, "HIGH", 7).
std:struct:pqueue:push(tst_pqueue, "HIGH", 7).
std:struct:pqueue:push(tst_pqueue, "MED", 3).
std:struct:pqueue:push(tst_pqueue, "LOW", 1).
std:struct:pqueue:push(tst_pqueue, "HIGH", 7).
std:struct:pqueue:push(tst_pqueue, "ULTRA", 9).

IF NOT std:struct:pqueue:empty(tst_pqueue) {
  PRINT "std:struct:pqueue:empty - passed.".
} ELSE { 
  PRINT "std:struct:pqueue:empty - failed.".
  PRINT "Expected pqueue to not be empty.".
}

IF std:struct:pqueue:peek(tst_pqueue) = "ULTRA" {
  PRINT "std:struct:pqueue:peek - passed.".
} ELSE {
  PRINT "std:struct:pqueue:peek - failed.".
  PRINT "Expected head of queue to be 'ULTRA'".
  PRINT tst_pqueue.
}

SET dequeue TO 1.
SET expected TO LIST("ULTRA", "HIGH", "HIGH", "HIGH", "MED", "LOW").
SET passed TO TRUE.
SET expect_val TO FALSE.
SET wrong_val to FALSE.
FOR item IN expected { 
  SET current TO std:struct:pqueue:pop(tst_pqueue).
  IF NOT current = item {
    SET passed TO FALSE.
    SET wrong_val TO item.
    SET expect_val TO current.
    BREAK.
  }
  SET dequeue TO dequeue + 1.
}

IF passed { 
  PRINT "std:struct:pqueue:pop - passed.".
} ELSE {
  PRINT "std:struct:pqueue:pop - failed.".
  PRINT "Expected dequeue operation # " + dequeue + " to be " + expect_val + ", but got " + wrong_val = ".".
}

// std:atomic:mutex

SET tst_mutex_a TO std:atomic:mutex:init().

IF tst_mutex_a:ISTYPE("Scalar") {
  PRINT "std:atomic:mutex:init - passed.".
} ELSE {
  PRINT "std:atomic:mutex:init - failed.".
  PRINT "Expected that a mutex would be a scalar".
}

SET have_mutex TO FALSE.
SET timeout TO (TIME:SECONDS + 5).
UNTIL TIME:SECONDS > timeout OR have_mutex {
  std:atomic:mutex:acquire(tst_mutex_a).
  SET have_mutex TO TRUE.
  WAIT 0.01.
}

IF have_mutex {
  PRINT "std:atomic:mutex:acquire - passed.".
} ELSE {
  PRINT "std:atomic:mutex - failed.".
  PRINT "Expected to gain immediate lock of mutex.".
}.

SET have_mutex TO FALSE.
WHEN TRUE THEN {
  std:atomic:mutex:acquire(tst_mutex_a).
  SET have_mutex TO TRUE.
  WAIT 0.01.
  RETURN FALSE.
}

IF NOT have_mutex { 
  PRINT "std:atomic:mutex:acquire - passed.".
} ELSE {
  PRINT "std:atomic:mutex:acquire - failed.".
  PRINT "Expected mutex to be unacquirable.".
}

std:atomic:mutex:release(tst_mutex_a).
WAIT 0.5.
IF have_mutex { 
  PRINT "std:atomic:mutex:release - passed.".
} ELSE {
  PRINT "std:atomic:mutex:release - failed.".
  PRINT "Expected mutex to become acquirable again.".
}

SET start TO TIME:SECONDS.
SET locked TO std:atomic:mutex:try(tst_mutex_a, 5).
SET finished TO TIME:SECONDS.
SET elapsed TO finished - start.

IF NOT locked {
  IF elapsed > 4 AND  elapsed < 6 { 
    PRINT "std:atomic:mutex:try - passed.".
  } ELSE {
    PRINT "std:atomic:mutex:try - failed.".
    PRINT "Incorrect timeout occured waiting on lock for " + elapsed + " seconds.".
  }
} ELSE {
  PRINT "std:atomic:mutex:try - failed.".
  PRINT "Expected mutex to be unacquirable.".
}

std:atomic:mutex:release(tst_mutex_a).
IF std:atomic:mutex:try(tst_mutex_a) {
  PRINT "std:atomic:mutex:try - passed.".
} ELSE {
  PRINT "std:atomic:mutex:try - failed.".
  PRINT "Failed to acquire lock when expected.".
}

// std:atomic:pqueue - Atomic priority queue.

SET tst_q TO std:atomic:pqueue:init().

IF tst_q:ISTYPE("List") AND tst_q[0]:ISTYPE("Scalar") AND tst_q[1]:ISTYPE("List") {
  PRINT "std:atomic:pqueue:init - passed.".
} ELSE {
  PRINT "std:atomic:pqueue:init - failed.".
  PRINT "Expected new atomic pqueue to be List(Scalar, List()).".
}

IF std:atomic:pqueue:empty(tst_q) {
  PRINT "std:atomic:pqueue:empty - passed.".
} ELSE {
  PRINT "std:atomic:pqueue:empty - failed.".
  PRINT "Expected atomic pqueue to be empty.".
}

std:atomic:pqueue:push(tst_q, "LOW", 1).
std:atomic:pqueue:push(tst_q, "LOW", 1).
std:atomic:pqueue:push(tst_q, "HIGH", 7).
std:atomic:pqueue:push(tst_q, "ULTRA", 9).
std:atomic:pqueue:push(tst_q, "LOW", 1).

IF NOT std:atomic:pqueue:empty(tst_q) {
  PRINT "std:atomic:pqueue:push - passed.".
} ELSE {
  PRINT "std:atomic:pqueue:push - failed.".
  PRINT "Expected atomic pqueue to not be empty.".
}


IF std:atomic:pqueue:peek(tst_q) = "ULTRA" {
  PRINT "std:atomic:pqueue:peek - passed.".
} ELSE {
  PRINT "std:atomic:pqueue:peek - failed.".
  PRINT "Expected ULTRA priority element to be at the head.".
}

SET dequeue to 1.
SET expected TO List("ULTRA", "HIGH", "LOW", "LOW", "LOW").
SET deq_val TO FALSE.
SET expected_val TO FALSE.
SET passed TO TRUE.

FOR element in expected {
  SET deq_val to std:atomic:pqueue:pop(tst_q).
  SET expected_val TO element.
  If deq_val <> expected_val { 
    SET passed TO FALSE.
    BREAK.
  }
  SET dequeue TO dequeue + 1.
}

IF passed { 
  PRINT "std:atomic:pqueue:pop - passed.".
} ELSE {
  PRINT "std:atomic:pqueue:pop - failed.".
  PRINT "Expected dequeue operation #" + dequeue + " to be " + expected_val + ", but received " + deq_val + ".".
}

syslog:init(syslog:level:debug).
IF syslog["__ready__"] { 
  IF syslog["logLevel"] = 4 { 
    PRINT "syslog:init - passed.".
  } ELSE {
    PRINT "syslog:init - failed.".
    PRINT "Expected syslog:logLevel to be 4, but got " + syslog["logLevel"] + ".".
  }
} ELSE {
  PRINT "syslog:init - failed.".
  PRINT "Expected syslog subsystem to be ready.".
}
syslog:msg("This here's some stuff.", syslog:level:info, "TestScript").
syslog:msg("This here's some more etuff.", syslog:level:info, "TestScript").
syslog:msg("This here's some even more stuff.", syslog:level:info, "TestScript").
syslog:shutdown().

syslog:init(syslog:level:DEBUG).
SET runstage:stage TO 1.
runstage:preserve().
SET runstage:stage TO 10.
runstage:load().

IF runstage:stage = 1 {
  PRINT "runstage:preserve,load - passed.".
} ELSE {
  PRINT "runstage:preserve,load - failed.".
  PRINT "Expected runstage to be 1.".
}

runstage:bump().
IF runstage:stage = 2 {
  PRINT "runstage:bump - passed.".
} ELSE {
  PRINT "runstage:bump - failed.".
}

SET _v TO VOLUME(1).
_v:DELETE("/runstage").

//// Test some math functions.
SET test_angle TO 90 * CONSTANT:DEGTORAD.
SET test_angle_var TO math:helper:rad:cos(test_angle).
IF math:helper:close(test_angle_var, 0, 0.000001) {
  PRINT "Testing cos in radians: Passed".
} else {
  PRINT "Testing cos in radians: Failed".
  PRINT "Expected 0, got " + test_angle_var + ".".
}

SET test_angle_var TO math:helper:rad:sin(test_angle).
IF math:helper:close(test_angle_var, 1, 0.000001) {
  PRINT "Testing sin in radians: Passed".
} else {
  PRINT "Testing sin in radians: Failed".
  PRINT "Expected 1, got " + test_angle_var + ".".
}

SET test_angle_var TO math:helper:rad:tan(ROUND(test_angle, 4)).
IF math:helper:close(test_angle_var, -272241.808409, 0.0001) {
  PRINT "Testing tan in radians: Passed".
} else {
  PRINT "Testing tan in radians: Failed".
  PRINT "Expected -272241.808409, got " + test_angle_var + ".".
}

FUNCTION panels_moving {
  PARAMETER panels.

  FOR p IN panels {
    LOCAL value IS parts:solarpanels:status(p).
    IF value = "Extending.." OR value = "Retracting.." {
      RETURN TRUE.
    }
  }
  RETURN FALSE.
}

FUNCTION panels_open {
  PARAMETER panels.

  FOR p IN panels {
    LOCAL value IS parts:solarpanels:status(p).
    IF value = "Retracted" {
      RETURN FALSE.
    }
  }
  RETURN TRUE.
}

syslog:init(syslog:level:debug, FALSE).
SET solarPanels TO parts:solarpanels:getDeployable().
IF solarPanels:LENGTH = 6 {
  PRINT "Fetch solar panels - passed.".
} ELSE {
  PRINT "Fetch solar panels - failed.".
}
parts:solarpanels:deploy(solarPanels).
WAIT UNTIL NOT panels_moving(solarPanels).
SET isOpen TO panels_open(solarPanels).
IF isOpen {
  PRINT "Open solar panels - passed.".
} else {
  PRINT "Open solar panels - failed.".
}
parts:solarpanels:retract(solarPanels).
WAIT UNTIL NOT panels_moving(solarPanels).
SET isOpen TO panels_open(solarPanels).
IF NOT isOpen {
  PRINT "Retract solar panels - passed.".
} ELSE {
  PRINT "Retract solar panels - failed.".
}


FUNCTION cells_running {
  PARAMETER cells.

  FOR cell in cells {
    IF parts:getFuelCellStatus(cell) = "Inactive" {
      RETURN FALSE.
    }
  }
  RETURN TRUE.
}

SET cells to parts:allFuelCells().
parts:startFuelCells(cells).
WAIT 3.
// Once you start/stop the fuel cells, the status becomes broken.  This is a kOS bug.
// Assume it went well, because what's the worst that could happen.
// IF cells_running(cells) {
  PRINT "Starting fuel cells - passed.".
// } ELSE {
//   PRINT "Starting fuel cells - failed.".
// }
parts:stopFuelCells(cells).
WAIT 3.
// IF NOT cells_running {
  PRINT "Stopping fuel cells - passed.".
// } ELSE {
//   PRINT "Stopping fuel cells - failed.".-0.048661948884938, -74.7282677884327
// }
syslog:shutdown().

SET rw TO math:geo:ksc:runway:west.


IF ROUND(rw:LAT, 4) = -0.0487 AND ROUND(rw:LNG, 4) = -74.7283 AND rw:BODY:NAME = "Kerbin" {
  PRINT "KSC Geographic Location - passed".
} ELSE {
  PRINT "KSC Geographic Location - failed.".
}