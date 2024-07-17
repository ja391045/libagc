////
// Library for a wrapper of sorts around messages.   This wrapper splits the message into two 
// distinct parts, the payload and the headers.  See lib/comms/ for how this is used.
////

GLOBAL std_struct_message IS LEXICON (
  "new",        std_struct_message_new@,
  "getPayload", std_struct_message_get_payload@,
  "setPayload", std_struct_message_set_payload@,
  "getHeader",  std_struct_message_get_header@,
  "setHeader",  std_struct_message_set_header@,
  "hasHeader",  std_struct_message_has_header@
).


////
// Initialize a new message.
// @PARAM _headers - The headers which must be of format Lexicon(Serializable, Serializable).  (Default: LEXICON()).
// @PARAM _payload - The payload data which must be of format Lexicon(Serializable, Serializable).  (Default: LEXICON()).
// @RETRUN - The initialized message.
////
FUNCTION std_struct_message_new {
  PARAMETER _headers IS LEXICON().
  PARAMETER _payload IS LEXICON().

  IF NOT _headers:ISTYPE("Lexicon") {
    SET _headers TO LEXICON().
  }

  IF NOT _payload:ISTYPE("Lexicon") {
    SET _payload TO LEXICON().
  }

  RETURN LEXICON("headers", _headers, "payload", _payload).
}


////
// Get a message's payload.  
// @PARAM _message - The message to retrive the payload for.
// @RETURN - The _message payload content.
////
FUNCTION std_struct_message_get_payload {
  PARAMETER _message.

  RETURN _message["payload"].
}

////
// Set a message's payload content.  This payload data will be passed into the comms_(vessel|cpu)_on_message() delegate.
// See: comms_vessel_on_message() and comms_cpu_on_message() for delegate registration.
// @PARAM _message - The message whose payload is to be set.
// @PARAM _payload - The payload to set.
//// 
FUNCTION std_struct_message_set_payload {
  PARAMETER _message.
  PARAMETER _payload.

  SET _message["payload"] TO _payload.
}

////
// Set a header in a message.   The entire header Lexicon will be passed into the comms_(vessel|cpu)_on_message matcher.
// See comms_vessel_on_message() and comms_cpu_on_message() for matcher registration.  A matcher typically associates a 
// message with a handler delegate.
// @PARAM _header_name  - The name of the header to set.
// @PARAM _header_value - The value of the header. 
// @PARAM _message      - The _message to set the header in.
// @RETURN - A reference to _message.
////
FUNCTION std_struct_message_set_header {
  PARAMETER _header_name.
  PARAMETER _header_value.
  PARAMETER _message.

  SET _message["headers"][_header_name] TO _header_value.
}

////
// Fetch a heaer from a message.
// @PARAM _header_name - The name of the header to fetch.
// @PARAM _message     - The message to fetch the header from. (Default: std_struct_message_new())
// @RETURN - The header value refernced by _header_name or FALSE if _header_name is not a valid key within the headers LEXICON.
//           Unfortunately this leads to the scenario of what happens when a header's actual value is literal FALSE.  But that's
//           a problem for another day.
////
FUNCTION std_struct_message_get_header {
  PARAMETER _header_name.
  PARAMETER _message.

  IF std_struct_message_has_header(_header_name, _message) {
    RETURN _message["headers"][_header_name].
  }
  RETURN FALSE.
}

////
// Check to see if a message has the header named.
// @PARAM _header_name - The name of the header to check.
// @PARAM _message     - The message whose headers should be checked.
// @RETURN - TRUE if the message headers contains the named header, FALSE otherwise.
FUNCTION std_struct_message_has_header {
  PARAMETER _header_name.
  PARAMETER _message.

  RETURN _message["headers"]:HASKEY(_header_name).
}
    

