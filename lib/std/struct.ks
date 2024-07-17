boot:require("std/struct/pqueue").
boot:require("std/struct/message").

GLOBAL std_struct IS LEXICON(
  "pqueue",  std_struct_pqueue,
  "message", std_struct_message
).
