boot:require("math").

SET _t TO math:eta:periapsis().
SET _b TO SHIP:ORBIT:ETA:PERIAPSIS.
IF math:helper:close(_t, _b, 0.05) {
    PRINT "Testing ETA Periapsis:  passed.".
} ELSE {
    PRINT "Testing ETA Periapsis:  faild.".
}

