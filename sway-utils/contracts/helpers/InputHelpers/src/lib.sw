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
    vec::Vec,
};

use BalancerErrors::*;

fn ensureInputLengthMatch(a: U128, b: U128) -> bool {
    require(a == b, INPUT_LENGTH_MISMATCH);
    return true;
}

fn ensureArrayIsSorted(vector: Vec<b256>) -> bool {


    // let mut vec: b256 = vector;

    if vector.len() < 2 {
        return false;
    }

    let mut a: u64 = 1;
    let mut previous = vector.get(0);
    while a < vec.len() {
        let mut current: b256 = vector.get(a);
        require(previous < current, UNSORTED_ARRAY);
        previous = current;
        a = a + 1;
    }
    
}  


