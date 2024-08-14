use core::box::BoxTrait;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks};
use plonky2_verifier::fields::goldilocks_quadratic::{GoldilocksQuadratic};
use plonky2_verifier::fields::utils::{sum_array, max_array, pow, shift_left};

pub struct FriOracleInfo {
    pub num_polys: u32,
    pub blinding: bool
}

pub struct FriPolynomialInfo {
    /// Index into `FriInstanceInfo`'s `oracles` list.
    pub oracle_index: u32,
    /// Index of the polynomial within the oracle.
    pub polynomial_index: u32,
}

/// A batch of openings at a particular point.
pub struct FriBatchInfo {
    pub point: GoldilocksQuadratic,
    pub polynomials: Array<FriPolynomialInfo>
}

/// Describes an instance of a FRI-based batch opening.
pub struct FriInstanceInfo {
    /// The oracles involved, not counting oracles created during the commit phase.
    pub oracles: Array<FriOracleInfo>,
    /// Batches of openings, where each batch is associated with a particular point.
    pub batches: Array<FriBatchInfo>,
}

/// Opened values of each polynomial that's opened at a particular point.
pub struct FriOpeningBatch {
    pub values: Array<GoldilocksQuadratic>
}

/// Opened values of each polynomial.
pub struct FriOpenings {
    pub batches: Array<FriOpeningBatch>
}

pub struct FriChallenges {
    // Scaling factor to combine polynomials.
    pub fri_alpha: GoldilocksQuadratic,
    // Betas used in the FRI commit phase reductions.
    pub fri_betas: Array<GoldilocksQuadratic>,
    pub fri_pow_response: Goldilocks,
    // Indices at which the oracle is queried in FRI.
    pub fri_oracle_indices: Array<u32>,
}

pub enum FriReductionStrategy {
    Fixed: Array<u32>,
    ConstantArityBits: (u32, u32),
}

pub struct FriConfig {
    pub rate_bits: u32,
    pub cap_height: u32,
    pub proof_of_work_bits: u32,
    pub reduction_strategy: FriReductionStrategy,
    pub num_query_rounds: u32,
}

pub struct FriParams {
    pub config: FriConfig,
    /// Whether to use a hiding variant of Merkle trees (where random salts are added to leaves).
    pub hiding: bool,
    /// The degree of the purported codeword, measured in bits.
    pub degree_bits: u32,
    /// The arity of each FRI reduction step, expressed as the log2 of the actual arity.
    /// For example, `[3, 2, 1]` would describe a FRI reduction tree with 8-to-1 reduction, then
    /// a 4-to-1 reduction, then a 2-to-1 reduction. After these reductions, the reduced polynomial
    /// is sent directly.
    pub reduction_arity_bits: Array<u32>,
}


#[generate_trait]
pub impl FriParamsImpl of FriParamsTrait {
    fn total_arities(self: @FriParams) -> u32 {
        sum_array(self.reduction_arity_bits.span())
    }

    fn max_arity_bits(self: @FriParams) -> u32 {
        max_array(self.reduction_arity_bits.span())
    }

    fn lde_bits(self: @FriParams) -> u32 {
        *self.degree_bits + *self.config.rate_bits
    }

    fn lde_size(self: @FriParams) -> u32 {
        shift_left(1, self.lde_bits())
    }

    fn final_poly_bits(self: @FriParams) -> u32 {
        *self.degree_bits - self.total_arities()
    }

    fn final_poly_len(self: @FriParams) -> u32 {
        shift_left(1, self.final_poly_bits())
    }
}
