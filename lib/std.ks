boot:require("std/err").
boot:require("std/string").
boot:require("std/struct").
boot:require("std/atomic").
boot:require("std/list").

GLOBAL std IS LEXICON (
    "string", std_string,
    "err",    std_err,
    "struct", std_struct,
    "atomic", std_atomic,
    "list", _list
).
