////
// This is the pre-boot environment, there are no underlying functions to rely on.
////

GLOBAL _BOOT_CACHE_DIR IS PATH("1:/cache/lib").
GLOBAL _BOOT_SOURCE_DIR IS PATH("0:/lib").

PRINT " =================  Welcome To ==================== ".
PRINT ".____    ._____.       _____    _________________   ".
PRINT "|    |   |__\_ |__    /  _  \  /  _____/\_   ___ \  ".
PRINT "|    |   |  || __ \  /  /_\  \/   \  ___/    \  \/  ".
PRINT "|    |___|  || \_\ \/    |    \    \_\  \     \____ ".
PRINT "|_______ \__||___  /\____|__  /\______  /\______  / ".
PRINT "        \/       \/         \/        \/        \/  ".
PRINT " ================================================== ".
PRINT " Booting - Stand By".

SET _BOOT_FAILED TO FALSE.
SET _BOOT_LIB TO PATH("boot.ks").
SET _BOOT_LIB_SRC TO _BOOT_SOURCE_DIR:COMBINE(_BOOT_LIB:NAME).
SET _BOOT_LIB_DST TO _BOOT_CACHE_DIR:COMBINE(_BOOT_LIB:NAME).
SET _DEBUG_BOOT TO FALSE.

PRINT " Preparing for local install to: '" + _BOOT_CACHE_DIR + "'.".
SET insDirIter TO _BOOT_CACHE_DIR:SEGMENTS:ITERATOR.
SET currentDir TO "".
UNTIL NOT insDirIter:NEXT {
  SET currentDir TO currentDir + "/" + insDirIter:VALUE.
  IF NOT _BOOT_CACHE_DIR:VOLUME:EXISTS(currentDir) {
    _BOOT_CACHE_DIR:VOLUME:CREATEDIR(currentDir).
  }
}

PRINT "    - Connect to KSC....".
SET now TO TIME:SECONDS.
SET timeout TO now + 10.
IF ADDONS:RT:AVAILABLE {
  UNTIL now > timeout OR ADDONS:RT:HASKSCCONNECTION(SHIP) {
    WAIT 0.5.
    SET now TO TIME:SECONDS.
  }

  IF now > timeout {
    PRINT "Failed.".
    SET _BOOT_FAILED TO TRUE.
  } else {
    PRINT "Success.".
  }
}

IF NOT _BOOT_FAILED {
  PRINT " Installing library bootloader....".
  IF _DEBUG_BOOT {
    COPYPATH(_BOOT_LIB_SRC, _BOOT_LIB_DST).
  } ELSE {
    SET _BOOT_LIB_DST TO _BOOT_LIB_DST:CHANGEEXTENSION("ksm").
    COMPILE _BOOT_LIB_SRC TO _BOOT_LIB_DST.
  }
  
  IF NOT _BOOT_LIB_DST:VOLUME:EXISTS(_BOOT_LIB_DST:SEGMENTS:JOIN("/")) {
    PRINT "Failed." AT (16, 35).
    SET _BOOT_FAILED TO TRUE.
  } ELSE {
    PRINT "Success." AT (16,35).
  }
}
IF NOT _BOOT_FAILED {
  RUNONCEPATH(_BOOT_LIB_DST).
}
