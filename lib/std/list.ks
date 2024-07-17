////
// Library with extra functionality for arrays.
////

GLOBAL _list IS LEXICON(
  "concat",    std_list_concat@,
	"mergeSort", std_list_merge_sort@
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

////
// Sort a list (using merge sort).  Shamelessly stolen form a reddit post.
// @PARAM _input_array - The list to sort.
////
FUNCTION std_list_merge_sort {
    PARAMETER _input_array.

    LOCAL input_length is _input_array:LENGTH.

    if input_length < 2 {
        RETURN.
    }

    LOCAL mid_index IS ROUND(input_length / 2).
    LOCAL left_half IS LIST().
    LOCAL right_half IS LIST().

    FROM {LOCAL i IS 0.} UNTIL i = mid_index STEP {SET i TO i + 1.} DO {
        left_half:ADD(0).
    }
    FROM {LOCAL i IS 0.} UNTIL i = (input_length - mid_index) STEP {SET i to i + 1.} DO {
        right_half:ADD(0).
    }
    FROM {LOCAL i IS 0.} UNTIL (i < mid_index) = FALSE STEP {SET i to i + 1.} DO {
        SET left_half[i] TO _input_array[i].
    }
    FROM {LOCAL i IS mid_index.} UNTIL (i < input_length) = FALSE STEP {SET i TO i + 1.} DO {
        SET right_half[i - mid_index] TO _input_array[i].
    }
    std_list_merge_sort(left_half).
   	std_list_merge_sort(right_half).
    __merge(_input_array, left_half, right_half).
    
    LOCAL FUNCTION __merge {
        LOCAL PARAMETER __array.
        LOCAL PARAMETER __left_half_arr.
        LOCAL PARAMETER __right_half_arr.

        LOCAL left_size is __left_half_arr:LENGTH.
        LOCAL right_size is __right_half_arr:LENGTH.
        LOCAL i is 0. 
				LOCAL j is 0.
				LOCAL k is 0.
        UNTIL NOT (i < left_size AND j < right_size){
            IF __left_half_arr[i] <= __right_half_arr[j] {
                SET __array[k] TO __left_half_arr[i].
                SET i TO i + 1.
            } ELSE {
                SET __array[k] TO __right_half_arr[j].
                SET j TO j + 1.
            }
            SET k TO k + 1.
        }
        UNTIL NOT(i < left_size) {
            SET __array[k] TO __left_half_arr[i].
            SET i TO i + 1.
            SET k TO k + 1.
        }
        UNTIL NOT ( j < right_size){
            SET __array[k] TO __right_half_arr[j].
            SET j TO j + 1.
            SET k TO k + 1.
        }
    }
}
