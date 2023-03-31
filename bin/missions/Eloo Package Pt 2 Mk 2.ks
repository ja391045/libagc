boot:require("runstage").
boot:require("staging").
boot:require("mnv").
boot:require("syslog").

syslog:init(syslog:level:info, FALSE).
runstage:load().
SET max_runstage TO 0.

UNTIL runstage:stage > max_runstage {
    PRINT "Runstage " + runstage:stage + ".".
    IF runstage:stage = 0 {
        mnv:node:do(60, FALSE, TRUE, 0).
    }
    syslog:upload().
    runstage:bump().
    runstage:preserve().
}
syslog:shutdown().