////
// Some Euclid math.
////

GLOBAL math_euclid IS LEXICON(
    "vectorDistance", math_euclid_vector_distance@
).

////
// Find the shortest line segment that would connect two vectors.
// @PARAM va - The first vector.
// @PARAM vb - The second vector.
// @RETURN - The length a line segment would have to be in order to connect the two vectors.
//
FUNCTION math_euclid_vector_distance {
    PARAMETER va.
    PARAMETER vb.

    RETURN SQRT( ( va:X - vb:X )^2 + ( va:Y - vb:Y )^2 + ( va:Z - vb:Z )^2).
}