contract;

abi MyContract {
    fn invariantRatio() -> u64;
    fn _calcOutGivenIn() -> u64;
    fn _calcInGivenOut() -> u64;
    fn _calcBptOutGivenExactTokensIn() -> u64;
    fn _calcTokenInGivenExactBptOut() -> u64;
    fn _calcAllTokensInGivenExactBptOut() -> u64;
    fn _calcBptInGivenExactTokensOut() -> u64;
    fn _calcTokensOutGivenExactBptIn() -> u64;
    fn _calcDueProtocolSwapFeeBptAmount() -> u64;
    fn _calcBptOutAddToken() -> u64;
}


// A minimum normalized weight imposes a maximum weight ratio. We need this due to limitations in the
// implementation of the power fn, as these ratios are often exponents.
const _MIN_WEIGHT: u64 = 1;
// Having a minimum normalized weight imposes a limit on the maximum number of tokens;
// i.e., the largest possible pool is one where all tokens have exactly the minimum weight.
const _MAX_WEIGHTED_TOKENS: u64 = 100;

// Pool limits that arise from limitations in the fixed point power fn (and the imposed 1:100 maximum weight
// ratio).

// Swap limits: amounts swapped may not be larger than this percentage of total balance.
const _MAX_IN_RATIO: u64 = 3;
const _MAX_OUT_RATIO: u64 = 3;

// Invariant growth limit: non-proportional joins cannot cause the invariant to increase by more than this ratio.
const _MAX_INVARIANT_RATIO: u64 = 3;
// Invariant shrink limit: non-proportional exits cannot cause the invariant to decrease by less than this ratio.
const _MIN_INVARIANT_RATIO: u64 = 7;

/**
* @dev Intermediate fn to avoid stack-too-deep errors.
*/
fn _computeJoinExactTokensInInvariantRatio(
    balances: [u64; 8],
    normalizedWeights: [u64; 8],
    amountsIn: [u64; 8],
    balanceRatiosWithFee: [u64; 8],
    invariantRatioWithFees: [u64; 8],
    swapFeePercentage: [u64; 8]
) -> u64 {
    // Swap fees are charged on all tokens that are being added in a larger proportion than the overall invariant
    // increase.
    let mut invariantRatio = ONE;

    let mut count = 0;
    while count < 8 {
        let amountInWithoutFee: u64 = 0;

        if balanceRatiosWithFee[count] > invariantRatioWithFees {
            let nonTaxableAmount = balances[count].mulDown(invariantRatioWithFees.sub(ONE));
            let taxableAmount = amountsIn[count].sub(nonTaxableAmount);
            let swapFee = taxableAmount.mulUp(swapFeePercentage);

            amountInWithoutFee = nonTaxableAmount.add(taxableAmount.sub(swapFee));
        } else {
            amountInWithoutFee = amountsIn[count];
        }
        let balanceRatio = balances[count].add(amountInWithoutFee).divDown(balances[count]);

        invariantRatio = invariantRatio.mulDown(balanceRatio.powDown(normalizedWeights[count]));
        
        count = count + 1;
        
        invariantRatio

    }

}

/**
    * @dev Intermediate fn to avoid stack-too-deep errors.
    */
fn _computeExitExactTokensOutInvariantRatio(
    balances: [u64; 8],
    normalizedWeights: [u64; 8],
    amountsOut: [u64; 8],
    balanceRatiosWithoutFee: [u64; 8],
    invariantRatioWithoutFees: u64,
    swapFeePercentage: u64
) -> u64 {
    invariantRatio = ONE;

    let mut count = 0;
    while count < 8 {
        // Swap fees are typically charged on 'token in', but there is no 'token in' here, so we apply it to
        // 'token out'. This results in slightly larger price impact.

        let amountOutWithFee: u64 = 0;
        if (invariantRatioWithoutFees > balanceRatiosWithoutFee[count]) {
            uint256 nonTaxableAmount = balances[count].mulDown(invariantRatioWithoutFees.complement());
            uint256 taxableAmount = amountsOut[count].sub(nonTaxableAmount);
            uint256 taxableAmountPlusFees = taxableAmount.divUp(swapFeePercentage.complement());

            amountOutWithFee = nonTaxableAmount.add(taxableAmountPlusFees);
        } else {
            amountOutWithFee = amountsOut[count];
        }

        let balanceRatio = balances[count].sub(amountOutWithFee).divDown(balances[count]);

        invariantRatio = invariantRatio.mulDown(balanceRatio.powDown(normalizedWeights[count]));
        
        count = count + 1;
        
        invariantRatio

    }
}



impl MyContract for Contract {
    // About swap fees on joins and exits:
    // Any join or exit that is not perfectly balanced (e.g. all single token joins or exits) is mathematically
    // equivalent to a perfectly balanced join or exit followed by a series of swaps. Since these swaps would charge
    // swap fees, it follows that (some) joins and exits should as well.
    // On these operations, we split the token amounts in 'taxable' and 'non-taxable' portions, where the 'taxable' part
    // is the one to which swap fees are applied.

    // Invariant is used to collect protocol swap fees by comparing its value between two times.
    // So we can round always to the same direction. It is also used to initiate the BPT amount
    // and, because there is a minimum BPT, we round down the invariant.
    fn _calculateInvariant(normalizedWeights: [u64; 8], balances: [u64; 8]) -> u64 {       
        /**********************************************************************************************
        // invariant               _____                                                             //
        // wi = weight index i      | |      wi                                                      //
        // bi = balance index i     | |  bi ^   = i                                                  //
        // i = invariant                                                                             //
        **********************************************************************************************/

        let invariant    = ONE;
        // for (uint256 i = 0; i < normalizedWeights.length; i++) {
        //     invariant = invariant.mulDown(balances[i].powDown(normalizedWeights[i]));
        // }
        let mut count = 0;
        while count < 8 {
            invariant = invariant.mulDown(balances[count].powDown(normalizedWeights[count]));
            count = count + 1;
        } 

        assert(invariant > 0, ZERO_INVARIANT);
        invariant
    }

    // Computes how many tokens can be taken out of a pool if `amountIn` are sent, given the
    // current balances and weights.
    fn _calcOutGivenIn(
        balanceIn: u64,
        weightIn: u64,
        balanceOut: u64,
        weightOut: u64,
        amountIn: u64
    ) -> u64 {
        /**********************************************************************************************
        // outGivenIn                                                                                //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /      /            bI             \    (wI / wO) \           //
        // aI = amountIn    aO = bO * |  1 - | --------------------------  | ^            |          //
        // wI = weightIn               \      \       ( bI + aI )         /              /           //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        // Amount out, so we round down overall.

        // The multiplication rounds down, and the subtrahend (power) rounds up (so the base rounds up too).
        // Because bI / (bI + aI) <= 1, the exponent rounds down.

        // Cannot exceed maximum in ratio
        assert(amountIn <= balanceIn.mulDown(_MAX_IN_RATIO), MAX_IN_RATIO); 

        let denominator: u64 = balanceIn.add(amountIn);
        let base: u64 = balanceIn.divUp(denominator);
        let exponent: u64 = weightIn.divDown(weightOut);
        let power: u64 = base.powUp(exponent);

        balanceOut.mulDown(power.complement())
    }

    // Computes how many tokens must be sent to a pool in order to take `amountOut`, given the
    // current balances and weights.
    fn _calcInGivenOut(
        balanceIn: u64,
        weightIn: u64,
        balanceOut: u64,
        weightOut: u64,
        amountOut: u64
    ) -> u64 {
        /**********************************************************************************************
        // inGivenOut                                                                                //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /  /            bO             \    (wO / wI)      \          //
        // aI = amountIn    aI = bI * |  | --------------------------  | ^            - 1  |         //
        // wI = weightIn               \  \       ( bO - aO )         /                   /          //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        // Amount in, so we round up overall.

        // The multiplication rounds up, and the power rounds up (so the base rounds up too).
        // Because b0 / (b0 - a0) >= 1, the exponent rounds up.

        // Cannot exceed maximum out ratio
        assert(amountOut <= balanceOut.mulDown(_MAX_OUT_RATIO), MAX_OUT_RATIO);

        let base = balanceOut.divUp(balanceOut.sub(amountOut));
        let exponent = weightOut.divUp(weightIn);
        let power = base.powUp(exponent);

        // Because the base is larger than one (and the power rounds up), the power should always be larger than one, so
        // the following subtraction should never revert.
        let ratio = power.sub(FixedPoint.ONE);

        balanceIn.mulUp(ratio)
    }

    fn _calcBptOutGivenExactTokensIn(
        balances: [u64; 8],
        normalizedWeights: [u64; 8],
        amountsIn: [u64; 8],
        bptTotalSupply: u64,
        swapFeePercentage: u64
    ) -> u64 {
        // BPT out, so we round down overall.

        let mut balanceRatiosWithFee: [u64; 8] = [-1, -1, -1, -1, -1, -1, -1, -1];

        let mut invariantRatioWithFees: u64 = 0;

        let mut count = 0;
        while count < 8 {
            balanceRatiosWithFee[count] = balances[count].add(amountsIn[count]).divDown(balances[count]);
            invariantRatioWithFees = invariantRatioWithFees.add(balanceRatiosWithFee[count].mulDown(normalizedWeights[count]));
            count = count + 1;
        }

        let invariantRatio = _computeJoinExactTokensInInvariantRatio(
            balances,
            normalizedWeights,
            amountsIn,
            balanceRatiosWithFee,
            invariantRatioWithFees,
            swapFeePercentage
        );

        if invariantRatio > FixedPoint.ONE {
            let bptOut = bptTotalSupply.mulDown(invariantRatio.sub(FixedPoint.ONE));
        } 
        else {
            let bptOut: u64 = 0;
        }
        bptOut
    }

    fn _calcTokenInGivenExactBptOut(
        balance: u64,
        normalizedWeight,: u64,
        bptAmountOut,: u64,
        bptTotalSupply,: u64,
        swapFeePercentage: u64
    ) -> u64 {
        /******************************************************************************************
        // tokenInForExactBPTOut                                                                 //
        // a = amountIn                                                                          //
        // b = balance                      /  /    totalBPT + bptOut      \    (1 / w)       \  //
        // bptOut = bptAmountOut   a = b * |  | --------------------------  | ^          - 1  |  //
        // bpt = totalBPT                   \  \       totalBPT            /                  /  //
        // w = weight                                                                            //
        ******************************************************************************************/

        // Token in, so we round up overall.

        // Calculate the factor by which the invariant will increase after minting BPTAmountOut
        let invariantRatio = bptTotalSupply.add(bptAmountOut).divUp(bptTotalSupply);
        assert(invariantRatio <= _MAX_INVARIANT_RATIO, MAX_OUT_BPT_FOR_TOKEN_IN);

        // Calculate by how much the token balance has to increase to match the invariantRatio
        let balanceRatio = invariantRatio.powUp(FixedPoint.ONE.divUp(normalizedWeight));

        let amountInWithoutFee = balance.mulUp(balanceRatio.sub(FixedPoint.ONE));

        // We can now compute how much extra balance is being deposited and used in virtual swaps, and charge swap fees
        // accordingly.
        let taxableAmount = amountInWithoutFee.mulUp(normalizedWeight.complement());
        let nonTaxableAmount = amountInWithoutFee.sub(taxableAmount);

        let taxableAmountPlusFees = taxableAmount.divUp(swapFeePercentage.complement());

        nonTaxableAmount.add(taxableAmountPlusFees)
    }

    fn _calcAllTokensInGivenExactBptOut(
        balances: [u64; 8],
        bptAmountOut: u64,
        totalBPT: u64
    ) -> [u64; 8] {
        /************************************************************************************
        // tokensInForExactBptOut                                                          //
        // (per token)                                                                     //
        // aI = amountIn                   /   bptOut   \                                  //
        // b = balance           aI = b * | ------------ |                                 //
        // bptOut = bptAmountOut           \  totalBPT  /                                  //
        // bpt = totalBPT                                                                  //
        ************************************************************************************/

        // Tokens in, so we round up overall.
        let bptRatio = bptAmountOut.divUp(totalBPT);

        let mut amountsIn: [u64; 8] = [-1, -1, -1, -1, -1, -1, -1, -1];

        let mut count = 0;
        while count < 8 {
            amountIn[count] = balances[i].mulUp(bptRatio);
            count = count + 1;
        }

        amountsIn
    }

    fn _calcBptInGivenExactTokensOut(
        balances: [u64; 8],
        normalizedWeights: [u64; 8],
        amountsOut: [u64; 8],
        bptTotalSupply: u64,
        swapFeePercentage: u64
    ) -> u64 {
        // BPT in, so we round up overall.

        let mut balanceRatiosWithoutFee: [u64; 8] = [-1, -1, -1, -1, -1, -1, -1, -1];
        let mut invariantRatioWithoutFees: u64 = 0;

        let mut count = 0;
        while count < 8 {
            balanceRatiosWithoutFee[count] = balances[count].sub(amountsOut[count]).divUp(balances[count]);
            invariantRatioWithoutFees = invariantRatioWithoutFees.add(
                balanceRatiosWithoutFee[count].mulUp(normalizedWeights[count])
            );
            count = count + 1;
        }

        let invariantRatio = _computeExitExactTokensOutInvariantRatio(
            balances,
            normalizedWeights,
            amountsOut,
            balanceRatiosWithoutFee,
            invariantRatioWithoutFees,
            swapFeePercentage
        );

        bptTotalSupply.mulUp(invariantRatio.complement())
    }

    fn _calcTokenOutGivenExactBptIn(
        balance: u64,
        normalizedWeight,: u64,
        bptAmountIn,: u64,
        bptTotalSupply,: u64,
        swapFeePercentage: u64
    ) -> u64 {
        /*****************************************************************************************
        // exactBPTInForTokenOut                                                                //
        // a = amountOut                                                                        //
        // b = balance                     /      /    totalBPT - bptIn       \    (1 / w)  \   //
        // bptIn = bptAmountIn    a = b * |  1 - | --------------------------  | ^           |  //
        // bpt = totalBPT                  \      \       totalBPT            /             /   //
        // w = weight                                                                           //
        *****************************************************************************************/

        // Token out, so we round down overall. The multiplication rounds down, but the power rounds up (so the base
        // rounds up). Because (totalBPT - bptIn) / totalBPT <= 1, the exponent rounds down.

        // Calculate the factor by which the invariant will decrease after burning BPTAmountIn
        let invariantRatio = bptTotalSupply.sub(bptAmountIn).divUp(bptTotalSupply);
        assert(invariantRatio >= _MIN_INVARIANT_RATIO, MIN_BPT_IN_FOR_TOKEN_OUT);

        // Calculate by how much the token balance has to decrease to match invariantRatio
        let balanceRatio = invariantRatio.powUp(FixedPoint.ONE.divDown(normalizedWeight));

        // Because of rounding up, balanceRatio can be greater than one. Using complement prevents reverts.
        let amountOutWithoutFee = balance.mulDown(balanceRatio.complement());

        // We can now compute how much excess balance is being withdrawn as a result of the virtual swaps, which result
        // in swap fees.

        // Swap fees are typically charged on 'token in', but there is no 'token in' here, so we apply it
        // to 'token out'. This results in slightly larger price impact. Fees are rounded up.
        let taxableAmount = amountOutWithoutFee.mulUp(normalizedWeight.complement());
        let nonTaxableAmount = amountOutWithoutFee.sub(taxableAmount);
        let taxableAmountMinusFees = taxableAmount.mulUp(swapFeePercentage.complement());

        nonTaxableAmount.add(taxableAmountMinusFees)
    }

    fn _calcTokensOutGivenExactBptIn(
        balances: [u64; 8],
        bptAmountIn: u64,
        totalBPT: u64
    ) -> [u64; 8] {
        /* *********************************************************************************************
        // exactBPTInForTokensOut                                                                    //
        // (per token)                                                                               //
        // aO = amountOut                  /        bptIn         \                                  //
        // b = balance           a0 = b * | ---------------------  |                                 //
        // bptIn = bptAmountIn             \       totalBPT       /                                  //
        // bpt = totalBPT                                                                            //
        **********************************************************************************************/

        // Since we're computing an amount out, we round down overall. This means rounding down on both the
        // multiplication and division.

        let bptRatio = bptAmountIn.divDown(totalBPT);

        let mut amountsOut: [u64; 8] = [-1, -1, -1, -1, -1, -1, -1, -1];
        
        let mut count = 0;
        while count < 8 {
            amountsOut[count] = balances[count].mulDown(bptRatio);
            count = count + 1;
        }

        amountsOut
    }

    fn _calcDueProtocolSwapFeeBptAmount(
        totalSupply: u64,
        previousInvariant: u64,
        currentInvariant: u64,
        protocolSwapFeePercentage: u64
    ) -> u64 {
        // We round down to prevent issues in the Pool's accounting, even if it means paying slightly less in protocol
        // fees to the Vault.
        let growth = currentInvariant.divDown(previousInvariant);

        // Shortcut in case there was no growth when comparing the current against the previous invariant.
        // This shouldn't happen outside of rounding errors, but have this safeguard nonetheless to prevent the Pool
        // from entering a locked state in which joins and exits revert while computing accumulated swap fees.
        if growth <= FixedPoint.ONE {
            0
        }

        // Assuming the Pool is balanced and token weights have not changed, a growth of the invariant translates into
        // proportional growth of all token balances. The protocol is due a percentage of that growth: more precisely,
        // it is due `k = protocol fee * (growth - 1) * balance / growth` for each token.
        // We compute the amount of BPT to mint for the protocol that would allow it to proportionally exit the Pool and
        // receive these balances. Note that the total BPT supply will increase when minting, so we need to account for
        // this in order to compute the percentage of Pool ownership the protocol will have.

        // The formula is:
        //
        // toMint = supply * k / (1 - k)

        // We compute protocol fee * (growth - 1) / growth, as we'll use that value twice.
        // There is no need to use SafeMath since we already checked growth is strictly greater than one.
        let k = protocolSwapFeePercentage.mulDown(growth - FixedPoint.ONE).divDown(growth);

        let numerator = totalSupply.mulDown(k);
        let denominator = k.complement();

        if denominator == 0 {
            0
        } else {
            numerator.divDown(denominator)
        }

    }

    /**
     * @dev Calculate the amount of BPT which should be minted when adding a new token to the Pool.
     *
     * Note that normalizedWeight is set that it corresponds to the desired weight of this token *after* adding it.
     * i.e. For a two token 50:50 pool which we want to turn into a 33:33:33 pool, we use a normalized weight of 33%
     * @param totalSupply - the total supply of the Pool's BPT.
     * @param normalizedWeight - the normalized weight of the token to be added (normalized relative to final weights)
     */
    fn _calcBptOutAddToken(totalSupply: u64, normalizedWeight: u64) -> u64 {
        // The amount of BPT which is equivalent to the token being added may be calculated by the growth in the
        // sum of the token weights, i.e. if we add a token which will make up 50% of the pool then we should receive
        // 50% of the new supply of BPT.
        //
        // The growth in the total weight of the pool can be easily calculated by:
        //
        // weightSumRatio = totalWeight / (totalWeight - newTokenWeight)
        //
        // As we're working with normalized weights `totalWeight` is equal to 1.

        let weightSumRatio = FixedPoint.ONE.divDown(FixedPoint.ONE.sub(normalizedWeight));

        // The amount of BPT to mint is then simply:
        //
        // toMint = totalSupply * (weightSumRatio - 1)

        totalSupply.mulDown(weightSumRatio.sub(FixedPoint.ONE))
    }
}
