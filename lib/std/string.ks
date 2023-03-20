GLOBAL std_string IS LEXICON(
    "sprintf", std_string_sprintf@
).

FUNCTION std_string_sprintf {
    PARAMETER format.
    PARAMETER subst.

    IF NOT subst:ISTYPE("Lexicon") {
        return format.
    }

    LOCAL result IS "".
    LOCAL matcher IS "".
    LOCAL replace IS 0.
    LOCAL result IS format.

    FOR key in subst:KEYS { 
       SET matcher TO "${" + key + "}".
       IF subst[key]:ISTYPE("String") {
        SET replace TO subst[key].
       } else {
         SET replace TO "" + subst[key].
       }
       SET result TO result:REPLACE(matcher, replace).
    }

    RETURN result.
}
