////
// library for manuever node manipulation.
///

boot:require("telemetry").
boot:require("math").
boot:require("syslog").
boot:require("staging").
boot:require("mnv/node").
boot:require("mnv/rendesvouz").

GLOBAL mnv IS LEXICON(
  "node",       mnv_node,
  "rendesvouz", mnv_rendesvouz
).
