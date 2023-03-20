////
// Library with extra functionality for arrays.
////

GLOBAL _list IS LEXICON(
  "concat", std_list_concat@
).

////
// Concatentate two lists.
// @PARAM a - The first list.
// @PARAM b - The second list.
// @RETURN A new list containing all the elements of A and B.
////
FUNCTION std_list_concat {
  PARAMETER a.
  PARAMETER b IS 0.

  LOCAL new IS LIST().
  LOCAL item IS FALSE.
  FOR item IN a {
    new:ADD(item).
  }
  FOR item IN b {
    new:ADD(item).
  }
  RETURN new.
}
