GLOBAL __boot_no_compile IS FALSE.

GLOBAL boot IS LEXICON(
  "require", boot_require@,
  "support", boot_support@
).


////
// Main require function.  Include a library script by path relative to lib.
// @PARAM - spath - The path to the library to include.
////
FUNCTION boot_require {
  PARAMETER spath.
  PARAMETER libPathSrc IS _BOOT_SOURCE_DIR.
  PARAMETER libPathDst IS _BOOT_CACHE_DIR.

  LOCAL fsPath IS spath + ".ks".

  LOCAL dirIter IS fspath:SPLIT("/"):ITERATOR.

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
    IF __boot_no_compile {
      COPYPATH(libPathSrc, libPathDst).
    } ELSE {
      SET libPathDst TO libPathDst:CHANGEEXTENSION("ksm").
      COMPILE libPathSrc TO libPathDst.
    }
  RUNONCEPATH(libPathDst).
}

FUNCTION boot_support {
  PARAMETER spath.

  boot_require(spath, PATH("0:/bin/support"), PATH("1:/bin/support")).
}

//**
// If We have a connection to KSC, see if there is a ship named executable available
// for download.  If so, download a fresh copy and run it.  If we do not have a connection
// to KSC, see if we have a local copy.  If we do, run it.
//**

SET _boot_execSrc TO _BOOT_SOURCE_DIR:PARENT:COMBINE("bin", "missions", SHIP:NAME + ".ks").
SET _boot_execDst TO _BOOT_CACHE_DIR:ROOT:COMBINE("bin", "missions", SHIP:NAME + ".ks").
IF HOMECONNECTION:ISCONNECTED {
  IF _boot_execSrc:VOLUME:EXISTS(_boot_execSrc:SEGMENTS:JOIN("/")) {
    PRINT "Updating Executable for " + SHIP:NAME + ".".
    COPYPATH(_boot_execSrc, _boot_execDst).
  }
}


IF _boot_execDst:VOLUME:EXISTS(_boot_execDst:SEGMENTS:JOIN("/")) {
  PRINT "Running executable for " + SHIP:NAME + ".".
  RUNPATH(_boot_execDst).
}
