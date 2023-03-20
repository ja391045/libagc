boot:require("std/atomic/mutex").
boot:require("std/struct/pqueue").

////
// A functional priority queue implementation with atomic operations.
////

GLOBAL std_atomic_pqueue IS LEXICON(
  "init",  std_atomic_pqueue_init@,
  "push",  std_atomic_pqueue_push@,
  "pop",   std_atomic_pqueue_pop@,
  "peek",  std_atomic_pqueue_peek@,
  "empty", std_atomic_pqueue_empty@
).

////
// Create a new atomic priority queue.
// @RETURN - List - An initialized priority queue structure.
////
FUNCTION std_atomic_pqueue_init {
  LOCAL under IS std_struct_pqueue:init().
  LOCAL mutex IS std_atomic_mutex:init().
  RETURN LIST(mutex, under).
}


////
// Enqueue an item into the atomic priority queue.
// @SEE - std:struct:pqueue:init
////
FUNCTION std_atomic_pqueue_push {
  PARAMETER pqueue.
  PARAMETER data.
  PARAMETER priority.

  std_atomic_mutex:acquire(pqueue[0]).
  std_struct_pqueue:push(pqueue[1], data, priority).
  std_atomic_mutex:release(pqueue[0]).
}

////
// Dequeue an item from an atomic prioroity queue.
// @SEE - std:struct:pueue:pop
////
FUNCTION std_atomic_pqueue_pop {
  PARAMETER pqueue.

  LOCAL haveItem IS FALSE.
  LOCAL item IS FALSE.

  UNTIL haveItem {
    std_atomic_mutex:acquire(pqueue[0]).
    IF pqueue[1]:LENGTH > 0 {
      SET item TO std_struct_pqueue:pop(pqueue[1]).
      SET haveItem TO TRUE.
    }
    std_atomic_mutex:release(pqueue[0]).
    IF NOT haveItem { WAIT 0.1. }
  }

  RETURN item.
}

////
// Look at the head of the atomic priority queue.
// @SEE - std:struct:pqueue:peek
////
FUNCTION std_atomic_pqueue_peek {
  PARAMETER pqueue.

  LOCAL haveItem IS FALSE.
  LOCAL item IS FALSE.

  UNTIL haveItem {
    std_atomic_mutex:acquire(pqueue[0]).
    IF pqueue[1]:LENGTH > 0 {
      SET item TO std_struct_pqueue:peek(pqueue[1]).
      SET haveItem TO TRUE.
    }
    std_atomic_mutex:release(pqueue[0]).
    IF NOT haveItem { WAIT 0.1. }
  }

  RETURN item.
}

////
// Check if the atomic priority queue is empty.
// @SEE std:struct:pqueue:empty
////
FUNCTION std_atomic_pqueue_empty {
  PARAMETER pqueue.

  LOCAL isEmpty IS TRUE.
  std_atomic_mutex:acquire(pqueue[0]).
  SET isEmpty TO std_struct_pqueue:empty(pqueue[1]).
  std_atomic_mutex:release(pqueue[0]).
  RETURN isEmpty.
}
