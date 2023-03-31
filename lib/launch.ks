////
// A library for ascent profile from the launch pad.
////

boot:require("staging").
boot:require("syslog").
boot:require("std").
boot:require("math").
boot:require("launch/profile").
boot:require("launch/rocket").

GLOBAL launch IS LEXICON(
  "profile", launch_profile,
  "rocket", launch_rocket
).