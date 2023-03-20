boot:require("telemetry/performance").
boot:require("telemetry/tsiolkovsky").

GLOBAL telemetry IS LEXICON(
  "performance", telemetry_performance,
  "tsiolkovsky", telemetry_tsiolkovsky
).
