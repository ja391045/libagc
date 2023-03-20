boot:require("std").
boot:require("syslog").
boot:require("math/helper").
boot:require("math/kepler").

// Library Functions.  Unpack the helper functions and put them at the top of the hierarchy,
// as I imagine they will be used often.
GLOBAL math IS LEXICON(
    "helper",  math_helper,
    "kepler" , math_kepler
).
