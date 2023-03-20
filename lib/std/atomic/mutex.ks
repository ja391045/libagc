GLOBAL std_atomic_mutex IS LEXICON(
  "init",       std_atomic_mutex_init@,
  "acquire",    std_atomic_mutex_acquire@,
  "try",        std_atomic_mutex_try@,
  "release",    std_atomic_mutex_release@,
  "__locks__",  LEXICON(),
  "__atomic__", TRUE,
  "__next__",   0
).

////
// Create a mutex.
// RETURN - Integer - The Mutex.
////
FUNCTION std_atomic_mutex_init {

  LOCAL mutex_id IS 0.

  WAIT UNTIL std_atomic_mutex["__atomic__"].
  SET std_atomic_mutex["__atomic__"] TO FALSE.

  SET mutex_id TO std_atomic_mutex["__next__"].
  std_atomic_mutex["__locks__"]:ADD(mutex_id, TRUE).
  SET std_atomic_mutex["__next__"] TO mutex_id + 1.

  SET std_atomic_mutex["__atomic__"] TO TRUE.

  RETURN mutex_id.
}

////
// Acquire an exclusive lock on the mutex.  This will block until the mutex is acquired.
// @PARAM - mutex - The mutex to lock.
////
FUNCTION std_atomic_mutex_acquire {
  PARAMETER mutex.

  WAIT UNTIL std_atomic_mutex["__locks__"][mutex].
  SET std_atomic_mutex["__locks__"][mutex] TO FALSE.
}

////
// Try to acquire a lock on the mutex with a timeout.  This will block until the mutex lock is
// acquired or until a timeout occurs.
// @PARAM  - mutex   - The mutex to lock.
// @PARAM  - timeout - How long in seconds to wait to acquire a mutex lock. (default: 30) 
// @RETURN - boolean - TRUE indicates a lock was acquired wihtin the timeout period, false indicates
//                     the operation timed out waiting on the lock.
///
FUNCTION std_atomic_mutex_try {
  PARAMETER mutex.
  PARAMETER timeout IS 30.

  LOCAL stop IS TIME:SECONDS + timeout.
  LOCAL haveLock IS FALSE.

  UNTIL TIME:SECONDS > stop OR haveLock {
    IF std_atomic_mutex["__locks__"][mutex] {
      SET std_atomic_mutex["__locks__"][mutex] TO FALSE.
      SET haveLock to TRUE.
    }
    WAIT 0.025.
  }
  RETURN haveLock.
}

////
// Release a lock on a mutex.
// @PARAM - mutex - The mutex to release.
////
FUNCTION std_atomic_mutex_release {
  PARAMETER mutex.
  SET std_atomic_mutex["__locks__"][mutex] TO TRUE.
}
