////
// library for manuever node manipulation.
///

boot:require("telemetry").
boot:require("math").
boot:require("syslog").
boot:require("staging").
boot:require("mnv/node").

GLOBAL mnv IS LEXICON(
  "node", mnv_node
).
