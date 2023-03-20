GLOBAL boot IS LEXICON(
  "require", boot_require@
).


////
// Main require function.  Include a library script by path relative to lib.
// @PARAM - spath - The path to the library to include.
////
FUNCTION boot_require {
  PARAMETER spath.

  LOCAL fsPath IS spath + ".ks".

  LOCAL dirIter IS fspath:SPLIT("/"):ITERATOR.
  LOCAL libPathSrc IS _BOOT_SOURCE_DIR.
  LOCAL libPathDst IS _BOOT_CACHE_DIR.

  UNTIL NOT dirIter:NEXT {
    SET libPathSrc TO libPathSrc:COMBINE(dirIter:VALUE).
    SET libPathDst TO libPathDst:COMBINE(dirIter:VALUE).
  }
  LOCAL noVolume IS libPathDst:SEGMENTS:JOIN("/").
    SET dirIter TO libPathDst:PARENT:SEGMENTS:ITERATOR.
    LOCAL currentDir IS "".
    UNTIL NOT dirIter:NEXT {
      SET currentDir TO currentDir + dirIter:VALUE + "/".
      IF NOT libPathDst:VOLUME:EXISTS(currentDir) {
        libPathDst:VOLUME:CREATEDIR(currentDir).
      }
    }
    COPYPATH(libPathSrc, libPathDst).
  RUNONCEPATH(libPathDst).
}

//**
// If We have a connection to KSC, see if there is a ship named executable available
// for download.  If so, download a fresh copy and run it.  If we do not have a connection
// to KSC, see if we have a local copy.  If we do, run it.
//**

SET _boot_execSrc TO _BOOT_SOURCE_DIR:PARENT:COMBINE("bin", "missions", SHIP:NAME + ".ks").
SET _boot_execDst TO _BOOT_CACHE_DIR:ROOT:COMBINE("bin", "missions", SHIP:NAME + ".ks").
//SET _boot_connected TO FALSE.
//SET _boot_now TO TIME:SECONDS.
//SET _boot_timeout TO _boot_now + 10.
//IF ADDONS:RT:AVAILABLE {
//  UNTIL _boot_now > _boot_timeout OR ADDONS:RT:HASKSCCONNECTION(SHIP) {
//    WAIT 0.5.
//    SET _boot_now TO TIME:SECONDS.
//  }
//
//  IF now <= timeout {
//    IF _boot_execSrc:VOLUME:EXISTS(_boot_execSrc:SEGMENTS:JOIN("/")) {
//      COPYPATH(_boot_execSrc, _boot_execDst).
//    }
//  } 
//} ELSE {
IF HOMECONNECTION:ISCONNECTED {
  IF _boot_execSrc:VOLUME:EXISTS(_boot_execSrc:SEGMENTS:JOIN("/")) {
    PRINT "Updating Executable for " + SHIP:NAME + ".".
    COPYPATH(_boot_execSrc, _boot_execDst).
  }
}
//}


IF _boot_execDst:VOLUME:EXISTS(_boot_execDst:SEGMENTS:JOIN("/")) {
  PRINT "Running executable for " + SHIP:NAME + ".".
  RUNPATH(_boot_execDst).
}
