boot:require("telemetry/performance").
boot:require("telemetry/tsiolkovsky").
boot:require("telemetry/visual").

GLOBAL telemetry IS LEXICON(
  "performance", telemetry_performance,
  "tsiolkovsky", telemetry_tsiolkovsky,
  "visual",      telemetry_visual
).
