GLOBAL std_err IS LEXICON(
    "strerr", std_err_strerr@
).


GLOBAL errno IS 0.

GLOBAL __std_err_errno IS LEXICON (
  100, "No such file or directory",
  101, "File exists",
  200, "Invalid argument",
  201, "Invalid state"
).

////
// Get a string description of a numeric error code if available.
// @PARAM  - errno  - The error number to get the description of.
// @RETURN - String - The description of the error.
////
FUNCTION std_err_strerr {
  PARAMETER errno.

  IF __std_err_errno:HASKEY(errno) {
    RETURN __std_err_errno[errno].
  }
  RETURN "Unspecified error".
}
