library WeightCompression;


use FixedPoint::*;
use std::{
    assert::{assert, require},
};

/**
     * @dev Compress a 64 bit value into `bitLength` bits.
     * To compress a value down to n bits, you first "normalize" it over the full input range.
     * For instance, if the maximum value were 10_000, and the `value` is 2_000, it would be
     * normalized to 0.2.
     *
     * Finally, "scale" that normalized value into the output range: adapting [0, maxUncompressedValue]
     * to [0, max n-bit value]. For n=8 bits, the max value is 255, so 0.2 corresponds to 51.
     * Likewise, for 16 bits, 0.2 would be stored as 13_107.
     */

fn compress(value: u64, bitLength: u64, maxUncompressedValue: u64) -> u64 {
    
    // It's not meaningful to compress 1-bit values (2 bits is also a bit silly, but theoretically possible).
    // 255 would likewise not be very helpful, but is technically valid.
    require(bitLength >= 2 && bitLength <= 255, "OUT_OF_BOUND");
    
    // The value cannot exceed the input range, or the compression would not "fit" in the output range.
    require(value <= maxUncompressedValue, "OUT_OF_BOUND");

    // There is another way this can fail: maxUncompressedValue * value can overflow, if either or both
    // are too big. Essentially, the maximum bitLength will be about 256 - (# bits needed for maxUncompressedValue).
    // It's not worth it to test for this: the caller is responsible for many things anyway, notably ensuring
    // compress and decompress are called with the same arguments, and packing the resulting value properly
    // (the most common use is to assist in packing several variables into a 256-bit word).

    let mut maxCompressedValue: u64 = (1 << bitLength) - 1;
    let mut v: u64 = mul_down(value, maxCompressedValue);
    let mut v2: u64 = div_down(v, maxCompressedValue);
    return v2;
}

 /**
     * @dev Reverse a compression operation, and restore the 256 bit value from a compressed value of
     * length `bitLength`. The compressed value is in the range [0, 2^(bitLength) - 1], and we are mapping
     * it back onto the uncompressed range [0, maxUncompressedValue].
     *
     * It is very important that the bitLength and maxUncompressedValue arguments are the
     * same for compress and decompress, or the results will be meaningless. This must be validated
     * externally.
     */
    fn decompress(
         value: u64,
         bitLength: u64,
         maxUncompressedValue: u64,
    ) -> u64 {
        // It's not meaningful to compress 1-bit values (2 bits is also a bit silly, but theoretically possible).
        // 255 would likewise not be very helpful, but is technically valid.
        require(bitLength >= 2 && bitLength <= 255, "OUT_OF_BOUNDS");
        let mut maxCompressedValue: u64 = (1 << bitLength) - 1;
        // The value must not exceed the maximum compressed value (2**(bitLength) - 1), or it will exceed the max
        // uncompressed value.
        require(value <= maxCompressedValue, "OUT_OF_BOUNDS");

        let mut v: u64 = mul_up(value, maxCompressedValue);
        let mut v2: u64 = div_down(v, maxCompressedValue);
        return v2;
    }

    // Special case overloads

    /**
     * @dev It is very common for the maximum value to be one: Weighted Pool weights, for example.
     * Overload for this common case, passing FixedPoint.ONE to the general `compress` function.
     */
    fn compress_(value: u64, bitLength: u64) -> u64 {
        return compress(value, bitLength, ONE);
    }

    /**
     * @dev It is very common for the maximum value to be one: Weighted Pool weights, for example.
     * Overload for this common case, passing FixedPoint.ONE to the general `decompress` function.
     */
    fn decompress_(value: u64, bitLength: u64) -> u64 {
        return decompress(value, bitLength, ONE);
    }


