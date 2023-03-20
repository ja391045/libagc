boot:require("std/atomic/mutex").
boot:require("std/atomic/pqueue").

GLOBAL std_atomic IS LEXICON(
  "mutex",  std_atomic_mutex,
  "pqueue", std_atomic_pqueue
).
