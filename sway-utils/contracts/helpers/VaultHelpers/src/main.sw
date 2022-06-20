library VaultHelpers;

use std::{address::Address};

fn toPoolAddress(poolId: b256) -> Address {
    let poolAddress: Address = ~Address::from(poolId);
    poolAddress
}
