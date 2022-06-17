library math;

use std::{
    assert::{assert,require},
    revert::revert
    };

// fn abs(a: u64) -> u64{
//     if a > 0 {
//         a
//     }else {
//         a = a - 2*a;
//     }
//     a
// }

fn add(a: u64, b: u64) -> u64{
    let mut c: u64 = a + b;
    require(c >= a, "Error");
    c
}

fn sub(a: u64, b: u64) -> u64 {
    require(b <= a, "Error" );
    let mut c: u64 = b - a;
    c
}

    fn max(a: u64, b: u64) -> u64 {
    let mut c: u64 = 0;
    if a >= b {
        c = a
    }else {
        c = b
    }
    c
}

fn min(a: u64, b: u64) -> u64 {
    let mut c: u64 = 0;
    if a < b {
        c = a
    }else {
        c = b
    }
    c
}

fn mul(a: u64, b: u64) -> u64 {
    let mut c: u64 = a * b;
    require (a == 0 || c / a == b, "Error");
    c
}

fn divDown(a: u64, b: u64) -> u64{
    require(b != 0, "Error");
    return a/b
}

fn divUp(a: u64, b: u64) -> u64 {
    require(b != 0, "Error"); 
    let mut c: u64 = 0;
    if a == 0 {
        c
    } else {
        c = 1 + (a-1)/b;
        c
    }
    c

}

