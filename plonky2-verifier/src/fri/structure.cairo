use core::box::BoxTrait;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks, GoldilocksZero};
use plonky2_verifier::fields::goldilocks_quadratic::{
    GoldilocksQuadratic, glq, GoldilocksQuadraticField
};
use plonky2_verifier::fields::utils::{sum_array, max_array, pow, shift_left};
use plonky2_verifier::plonk::circuit_data::Range;

#[derive(Drop, Copy, Debug)]
pub struct FriOracleInfo {
    pub num_polys: usize,
    pub blinding: bool
}

#[derive(Drop, Copy, Debug)]
pub struct FriPolynomialInfo {
    /// Index into `FriInstanceInfo`'s `oracles` list.
    pub oracle_index: usize,
    /// Index of the polynomial within the oracle.
    pub polynomial_index: usize,
}

#[generate_trait]
pub impl FriPolynomialInfoImpl of FriPolynomialInfoTrait {
    fn from_range(
        oracle_index: usize, plynomial_indecies: Range<usize>
    ) -> Array<FriPolynomialInfo> {
        let mut result = array![];
        let mut i = plynomial_indecies.start;
        while i < plynomial_indecies
            .end {
                result.append(FriPolynomialInfo { oracle_index, polynomial_index: i });
                i += 1;
            };
        result
    }
}

/// A batch of openings at a particular point.
#[derive(Drop, Debug)]
pub struct FriBatchInfo {
    pub point: GoldilocksQuadratic,
    pub polynomials: Array<FriPolynomialInfo>
}

/// Describes an instance of a FRI-based batch opening.
#[derive(Drop, Debug)]
pub struct FriInstanceInfo {
    /// The oracles involved, not counting oracles created during the commit phase.
    pub oracles: Array<FriOracleInfo>,
    /// Batches of openings, where each batch is associated with a particular point.
    pub batches: Array<FriBatchInfo>,
}

/// Opened values of each polynomial that's opened at a particular point.
#[derive(Drop, Copy, Debug)]
pub struct FriOpeningBatch {
    pub values: Span<GoldilocksQuadratic>
}

/// Opened values of each polynomial.
#[derive(Drop, Debug)]
pub struct FriOpenings {
    pub batches: Array<FriOpeningBatch>
}

#[derive(Drop, Debug, PartialEq)]
pub struct FriChallenges {
    // Scaling factor to combine polynomials.
    pub fri_alpha: GoldilocksQuadratic,
    // Betas used in the FRI commit phase reductions.
    pub fri_betas: Array<GoldilocksQuadratic>,
    pub fri_pow_response: Goldilocks,
    // Indices at which the oracle is queried in FRI.
    pub fri_query_indices: Array<usize>,
}

#[derive(Drop, Clone, Debug)]
pub enum FriReductionStrategy {
    Fixed: Array<usize>,
    ConstantArityBits: (usize, usize),
}

#[derive(Drop, Clone, Debug)]
pub struct FriConfig {
    pub rate_bits: usize,
    pub cap_height: usize,
    pub proof_of_work_bits: usize,
    pub reduction_strategy: FriReductionStrategy,
    pub num_query_rounds: usize,
}

#[derive(Drop, Debug)]
pub struct FriParams {
    pub config: FriConfig,
    /// Whether to use a hiding variant of Merkle trees (where random salts are added to leaves).
    pub hiding: bool,
    /// The degree of the purported codeword, measured in bits.
    pub degree_bits: usize,
    /// The arity of each FRI reduction step, expressed as the log2 of the actual arity.
    /// For example, `[3, 2, 1]` would describe a FRI reduction tree with 8-to-1 reduction, then
    /// a 4-to-1 reduction, then a 2-to-1 reduction. After these reductions, the reduced polynomial
    /// is sent directly.
    pub reduction_arity_bits: Array<usize>,
}


#[derive(Drop, Debug)]
pub struct ReducingFactor {
    pub base: GoldilocksQuadratic,
    pub count: u64,
}

#[generate_trait]
pub impl ReducingFactorImpl of ReducingFactorTrait {
    fn new(base: GoldilocksQuadratic) -> ReducingFactor {
        ReducingFactor { base: base, count: 0 }
    }

    fn mul(ref self: ReducingFactor, x: GoldilocksQuadratic) -> GoldilocksQuadratic {
        self.count += 1;
        self.base * x
    }

    fn reduce(
        ref self: ReducingFactor, batch_values: Span<GoldilocksQuadratic>
    ) -> GoldilocksQuadratic {
        let mut acc = glq(0);

        // reverse the array
        let mut i = batch_values.len();
        while i > 0 {
            i -= 1;
            let value = *batch_values.get(i).unwrap().unbox();
            acc = self.mul(acc) + value;
        };

        acc
    }

    fn shift(ref self: ReducingFactor, x: GoldilocksQuadratic) -> GoldilocksQuadratic {
        let tmp = self.base.exp_u64(self.count) * x;
        self.count = 0;
        tmp
    }
}

#[generate_trait]
pub impl FriParamsImpl of FriParamsTrait {
    fn total_arities(self: @FriParams) -> usize {
        sum_array(self.reduction_arity_bits.span())
    }

    fn max_arity_bits(self: @FriParams) -> usize {
        max_array(self.reduction_arity_bits.span())
    }

    fn lde_bits(self: @FriParams) -> usize {
        *self.degree_bits + *self.config.rate_bits
    }

    fn lde_size(self: @FriParams) -> usize {
        shift_left(1, self.lde_bits())
    }

    fn final_poly_bits(self: @FriParams) -> usize {
        *self.degree_bits - self.total_arities()
    }

    fn final_poly_len(self: @FriParams) -> usize {
        shift_left(1, self.final_poly_bits())
    }
}

#[derive(Drop, Debug, PartialEq, Eq)]
pub struct PrecomputedReducedOpenings {
    pub reduced_openings_at_point: Array<GoldilocksQuadratic>
}

#[generate_trait]
pub impl PrecomputedReducedOpeningsImpl of PrecomputedReducedOpeningsTrait {
    fn from_os_and_alpha(
        openings: @FriOpenings, alpha: @GoldilocksQuadratic
    ) -> PrecomputedReducedOpenings {
        let mut reduced_openings_at_point = array![];

        let mut i = 0;
        let len = openings.batches.len();

        while i < len {
            let batch = *openings.batches.get(i).unwrap().unbox();
            let mut reducing_factor = ReducingFactorImpl::new(*alpha);
            let reduced = reducing_factor.reduce(batch.values);
            reduced_openings_at_point.append(reduced);
            i += 1;
        };

        PrecomputedReducedOpenings { reduced_openings_at_point }
    }
}


#[cfg(test)]
pub mod tests {
    use super::{
        ReducingFactor, FriOpeningBatch, FriOpenings, PrecomputedReducedOpeningsImpl,
        ReducingFactorImpl, GoldilocksQuadratic, glq
    };
    #[cairofmt::skip]
    fn glq_0_15() -> Array<GoldilocksQuadratic> {
        array![
            glq(0), glq(1), glq(2), glq(3), glq(4),
            glq(5), glq(6), glq(7), glq(8), glq(9),
            glq(10), glq(11), glq(12), glq(13), glq(14),
            glq(15)
        ]
    }
    #[cairofmt::skip]
    fn glq_15_31() -> Array<GoldilocksQuadratic> {
        array![
            glq(15), glq(16), glq(17), glq(18), glq(19),
            glq(20), glq(21), glq(22), glq(23), glq(24),
            glq(25), glq(26), glq(27), glq(28), glq(29),
            glq(30), glq(31)
        ]
    }

    #[test]
    fn test_reduce() {
        let base = glq(10);

        let mut reducing_factor = ReducingFactorImpl::new(base);
        let result = reducing_factor.reduce(glq_0_15().span());
        assert_eq!(result, glq(16543209876543210));
    }

    #[test]
    fn test_opening() {
        let alpha = glq(10);
        let openings = FriOpenings {
            batches: array![
                FriOpeningBatch { values: glq_0_15().span() },
                FriOpeningBatch { values: glq_15_31().span() }
            ]
        };

        let precomputed = PrecomputedReducedOpeningsImpl::from_os_and_alpha(@openings, @alpha);

        assert_eq!(
            precomputed.reduced_openings_at_point,
            array![glq(16543209876543210), glq(343209876543209875)]
        );
    }
}
