boot:require("telemetry/performance").
boot:require("telemetry/tsiolkovsky").
boot:require("telemetry/visual").
boot:require("telemetry/status").

GLOBAL telemetry IS LEXICON(
  "performance", telemetry_performance,
  "tsiolkovsky", telemetry_tsiolkovsky,
  "visual",      telemetry_visual,
  "status",      telemetry_status
).