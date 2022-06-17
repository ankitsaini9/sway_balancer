library InputHelpers;

use std::{
    address::*,
    assert::{assert, require},
    block::*,
    chain::auth::*,
    context::{*, call_frames::*},
    contract_id::ContractId,
    hash::*,
    result::*,
    revert::revert,
    storage::*,
    token::*,
    u128::U128,
};

use BalancerErrors::*;

fn ensureInputLengthMatch(a: U128, b: U128) -> bool {
    require(a == b, INPUT_LENGTH_MISMATCH);
    return true
}

fn ensureArrayIsSorted(array:[b256;10]) -> bool {
    // if (array.length() < 2){
    //     return false;
    // }

    let mut a = 1;
    let mut previous: b256 = array[0];
    while a < array.len() {
        let mut current: b256 = array[a];
        require(previous < current, UNSORTED_ARRAY);
        previous = current;
        a = a + 1;
    }
    
}  


