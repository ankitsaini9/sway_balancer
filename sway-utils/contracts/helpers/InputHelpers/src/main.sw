library InputHelpers;

use BalancerErrors::*;

fn ensureInputLengthMatch(a: U128, b: U128) -> bool {
    require(a == b, INPUT_LENGTH_MISMATCH);
    return true
}

fn ensureArrayIsSorted(vector:Vec<b256>) -> bool {


    let mut vec: Vec<b256> = vector;

    if vec.len() < 2 {
        return false;
    }

    let mut a = 1;
    let mut previous: b256 = vec.get(0);
    while a < vec.len() {
        let mut current: b256 = vec.get[a];
        require(previous < current, UNSORTED_ARRAY);
        previous = current;
        a = a + 1;
    }
    
}  


