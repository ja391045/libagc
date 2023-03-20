////
// Functional implementation of priority queue.
////

GLOBAL std_struct_pqueue IS LEXICON(
  "init",  std_struct_pqueue_init@,
  "push",  std_struct_pqueue_push@,
  "pop",   std_struct_pqueue_pop@,
  "peek",  std_struct_pqueue_peek@,
  "empty", std_struct_pqueue_empty@
).

////
// Creates a new priority queue instance, backed by LIST().
// @RETURN - List - New priority queue.
////
FUNCTION std_struct_pqueue_init {
  RETURN LIST().
}

////
// Enqueue an element into the queue.
// @PARAM - pqueue   - The queue to perform the operation on.
// @PARAM - data     - The element to enqueue.
// @PARAM - priority - An integer from 0-9 which specifies the priroity any
//                     value less than 0 will be treated as 0, and any value
//                     higher than 9 will be treated as 9. Higher values are 
//                     higher priority.   (Default: 9)
////
FUNCTION std_struct_pqueue_push {
  PARAMETER pqueue.
  PARAMETER data.
  PARAMETER priority IS 9.

  IF priority < 0 { 
    SET priority TO 0.
  } ELSE IF priority > 9 {
    SET priority TO 9.
  }

  IF pqueue:LENGTH < priority {
    pqueue:ADD(data).
  } else {
    pqueue:INSERT(priority, data).
  }
}


////
// Dequeue the next element from the priority queue.  This function
// will block until queue data becomes available.
// @PARAM  - pqueue - The queue to perform the operation on.
// @RETURN - Any    - The data element.
////
FUNCTION std_struct_pqueue_pop {
  PARAMETER pqueue.

  WAIT UNTIL NOT std_struct_pqueue_empty(pqueue).
  LOCAL idx IS pqueue:LENGTH - 1.
  LOCAL value IS pqueue[idx].
  pqueue:REMOVE(idx).
  RETURN value.
}

////
// Check and see if the queue has any data to deliver.
// @RETURN - boolean - True if data is waiting, false otherwise.
////
FUNCTION std_struct_pqueue_empty {
  PARAMETER pqueue.

  RETURN (pqueue:LENGTH = 0).
}

////
// Peek at the head of the queue.
// RETURN - Any - The head element from the queue.
////
FUNCTION std_struct_pqueue_peek {
  PARAMETER pqueue.

  WAIT UNTIL NOT std_struct_pqueue_empty(pqueue).
  LOCAL idx IS pqueue:LENGTH - 1.
  return pqueue[idx].
}
