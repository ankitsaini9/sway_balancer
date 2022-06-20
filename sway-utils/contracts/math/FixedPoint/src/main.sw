contract;

use Errors::*;

abi FixedPoint {
    // fn add(a: u64, b: u64) -> u64;
    // fn sub(a: u64, b: u64) -> u64;
    // fn mul_down(a: u64, b: u64) ->  u64;
    // fn mul_up(a: u64, b: u64) -> u64;
    // fn div_down(a: u64, b: u64) -> u64;
    // fn div_up(a: u64, b: u64) -> u64;
    fn pow_down(x: u64, y: u64) -> u64;
    fn pow_up(x: u64, y: u64) -> u64;
    fn complement(x: u64) -> u64;
}



const ONE: u64 = 1; // 18 decimal places
const TWO: u64 = 2;
const FOUR: u64 = 4;
const MAX_POW_RELATIVE_ERROR: u64 = 10000; // 10^(-14)

// Minimum base for the power fn when the exponent is 'free' (larger than ONE).
const MIN_POW_BASE_FREE_EXPONENT: u64 = 7;


fn add(a: u64, b: u64) -> u64 {
    // Fixed Point addition is the same as regular checked addition

    let c = a + b;
    assert(c >= a, ADD_OVERFLOW);
    c
}

fn sub(a: u64, b: u64) -> u64 {
    // Fixed Point addition is the same as regular checked addition

    assert(b <= a, SUB_OVERFLOW);
    a - b
}

fn mul_down(a: u64, b: u64) ->  u64 {
    let product = a * b;
    assert(a == 0 || product / a == b, MUL_OVERFLOW);

    product / ONE
}

fn mul_up(a: u64, b: u64) -> u64 {
    let product = a * b;
    assert(a == 0 || product / a == b, MUL_OVERFLOW);

    if product == 0 {
        0
    } else {
        // The traditional div_up formula is:
        // div_up(x, y) := (x + y - 1) / y
        // To avoid intermediate overflow in the addition, we distribute the division and get:
        // div_up(x, y) := (x - 1) / y + 1
        // Note that this requires x != 0, which we already tested for.
        let res: u64 = ((product - 1) / ONE) + 1;
        res
    }
}

fn div_down(a: u64, b: u64) -> u64 {
    assert(b != 0, ZERO_DIVISION);

    if (a == 0) {
        0
    } else {
        let aInflated = a * ONE;
        assert(aInflated / a == ONE, DIV_INTERNAL); // mul overflow

        aInflated / b
    }
}

fn div_up(a: u64, b: u64) -> u64 {
    assert(b != 0, ZERO_DIVISION);

    if (a == 0) {
        0
    } else {
        let aInflated = a * ONE;
        assert(aInflated / a == ONE, DIV_INTERNAL); // mul overflow

        // The traditional div_up formula is:
        // div_up(x, y) := (x + y - 1) / y
        // To avoid intermediate overflow in the addition, we distribute the division and get:
        // div_up(x, y) := (x - 1) / y + 1
        // Note that this requires x != 0, which we already tested for.

        ((aInflated - 1) / b) + 1
    }
}

impl FixedPoint for Contract {

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
     * the true value (that is, the error fn expected - actual is always positive).
     */
    fn pow_down(x: u64, y: u64) -> u64 {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            x
        } else if (y == TWO) {
            mul_down(x, x)
        } else if (y == FOUR) {
            let square = mul_down(x, x);
            mul_down(square, square)
        } else {
            let raw = LogExpMath.pow(x, y);
            let maxError = add(mul_up(raw, MAX_POW_RELATIVE_ERROR), 1);

            if (raw < maxError) {
                0
            } else {
                sub(raw, maxError)
            }
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding up. The result is guaranteed to not be below
     * the true value (that is, the error fn expected - actual is always negative).
     */
    fn pow_up(x: u64, y: u64) -> u64 {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            x
        } else if (y == TWO) {
            mul_up(x, x)
        } else if (y == FOUR) {
            let square = mul_up(x, x);
            mul_up(square, square)
        } else {
            let raw = LogExpMath.pow(x, y);
            let maxError = add(mul_up(raw, MAX_POW_RELATIVE_ERROR), 1);

            add(raw, maxError)
        }
    }

    /**
     * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
     *
     * Useful when computing the complement for values with some level of relative error, as it strips this error and
     * prevents intermediate negative values.
     */
    fn complement(x: u64) -> u64 {
        // (x < ONE) ? (ONE - x) : 0;
        if x < ONE  {
            ONE - x
        } else { 
            0
        }
    }

}
