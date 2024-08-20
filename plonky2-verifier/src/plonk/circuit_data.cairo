use core::array::ArrayTrait;
use plonky2_verifier::fri::structure::{
    FriParams, FriConfig, FriInstanceInfo, FriBatchInfo, FriOracleInfo, FriPolynomialInfo,
    FriPolynomialInfoImpl
};
use plonky2_verifier::hash::structure::HashOut;
use plonky2_verifier::fields::goldilocks::Goldilocks;
use plonky2_verifier::fields::goldilocks_quadratic::{GoldilocksQuadratic, GoldilocksQuadraticField};
use plonky2_verifier::hash::merkle_caps::MerkleCaps;

#[derive(Drop, Debug)]
pub struct CircuitConfig {
    /// The number of wires available at each row. This corresponds to the "width" of the circuit,
    /// and consists in the sum of routed wires and advice wires.
    pub num_wires: usize,
    /// The number of routed wires, i.e. wires that will be involved in Plonk's permutation argument.
    /// This allows copy constraints, i.e. enforcing that two distant values in a circuit are equal.
    /// Non-routed wires are called advice wires.
    pub num_routed_wires: usize,
    /// The number of constants that can be used per gate. If a gate requires more constants than the config
    /// allows, the [`CircuitBuilder`] will complain when trying to add this gate to its set of gates.
    pub num_constants: usize,
    /// Whether to use a dedicated gate for base field arithmetic, rather than using a single gate
    /// for both base field and extension field arithmetic.
    pub use_base_arithmetic_gate: bool,
    pub security_bits: usize,
    /// The number of challenge points to generate, for IOPs that have soundness errors of (roughly)
    /// `degree / |F|`.
    pub num_challenges: usize,
    /// A boolean to activate the zero-knowledge property. When this is set to `false`, proofs *may*
    /// leak additional information.
    pub zero_knowledge: bool,
    /// A cap on the quotient polynomial's degree factor. The actual degree factor is derived
    /// systematically, but will never exceed this value.
    pub max_quotient_degree_factor: usize,
    pub fri_config: FriConfig,
}

#[derive(Drop, Debug)]
pub struct Range<Idx> {
    pub start: Idx,
    pub end: Idx,
}

#[derive(Drop, Debug)]
pub struct SelectorsInfo {
    pub(crate) selector_indices: Array<usize>,
    pub(crate) groups: Array<Range<usize>>,
}

#[generate_trait]
impl SelectorsInfoImpl of SelectorsInfoTrait {
    fn num_selectors(self: @SelectorsInfo) -> usize {
        self.groups.len()
    }
}

#[derive(Drop, Debug)]
pub struct PlonkOracle {
    index: usize,
    blinding: bool,
}

#[generate_trait]
pub impl PlonkOracleImpl of PlonkOracleTrait {
    fn CONSTANTS_SIGMAS() -> PlonkOracle {
        PlonkOracle { index: 0, blinding: false }
    }

    fn WIRES() -> PlonkOracle {
        PlonkOracle { index: 1, blinding: true, }
    }

    fn ZS_PARTIAL_PRODUCTS() -> PlonkOracle {
        PlonkOracle { index: 2, blinding: true, }
    }

    fn QUOTIENT() -> PlonkOracle {
        PlonkOracle { index: 3, blinding: true, }
    }
}

#[derive(Drop, Debug)]
pub struct CommonCircuitData {
    pub config: CircuitConfig,
    pub fri_params: FriParams,
    pub selectors_info: SelectorsInfo,
    pub quotient_degree_factor: usize,
    pub num_gate_constraints: usize,
    pub num_constants: usize,
    pub num_public_inputs: usize,
    pub k_is: Array<Goldilocks>,
    pub num_partial_products: usize,
    pub num_lookup_polys: usize,
    pub num_lookup_selectors: usize,
}

#[generate_trait]
pub impl CommonCircuitDataImpl of CommonCircuitDataTrait {
    fn degree_bits(self: @CommonCircuitData) -> usize {
        *self.fri_params.degree_bits
    }

    fn get_fri_instance(self: @CommonCircuitData, zeta: GoldilocksQuadratic) -> FriInstanceInfo {
        let zeta_batch = FriBatchInfo { point: zeta, polynomials: self.fri_all_polys() };

        let g = GoldilocksQuadraticField::primitive_root_of_unity(self.degree_bits());
        let zeta_next = g * zeta;
        let zeta_next_batch = FriBatchInfo {
            point: zeta_next, polynomials: self.fri_next_batch_polys(),
        };

        let openings = array![zeta_batch, zeta_next_batch];
        FriInstanceInfo { oracles: self.fri_oracles(), batches: openings, }
    }

    fn fri_oracles(self: @CommonCircuitData) -> Array<FriOracleInfo> {
        let mut oracles = ArrayTrait::new();
        oracles
            .append(
                FriOracleInfo {
                    num_polys: self.num_preprocessed_polys(),
                    blinding: PlonkOracleImpl::CONSTANTS_SIGMAS().blinding,
                }
            );
        oracles
            .append(
                FriOracleInfo {
                    num_polys: *self.config.num_wires, blinding: PlonkOracleImpl::WIRES().blinding,
                }
            );
        oracles
            .append(
                FriOracleInfo {
                    num_polys: self.num_zs_partial_products_polys() + self.num_all_lookup_polys(),
                    blinding: PlonkOracleImpl::ZS_PARTIAL_PRODUCTS().blinding,
                }
            );
        oracles
            .append(
                FriOracleInfo {
                    num_polys: self.num_quotient_polys(),
                    blinding: PlonkOracleImpl::QUOTIENT().blinding,
                }
            );
        oracles
    }

    fn sigmas_range(self: @CommonCircuitData) -> Range<usize> {
        Range {
            start: *self.num_constants, end: *self.num_constants + *self.config.num_routed_wires
        }
    }

    fn num_preprocessed_polys(self: @CommonCircuitData) -> usize {
        self.sigmas_range().end
    }

    fn fri_preprocessed_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::CONSTANTS_SIGMAS().index,
            Range { start: 0, end: self.num_preprocessed_polys() },
        )
    }

    fn fri_wire_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        let num_wire_polys = *self.config.num_wires;
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::WIRES().index, Range { start: 0, end: num_wire_polys }
        )
    }

    fn fri_zs_partial_products_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::ZS_PARTIAL_PRODUCTS().index,
            Range { start: 0, end: self.num_zs_partial_products_polys() },
        )
    }

    fn num_zs_partial_products_polys(self: @CommonCircuitData) -> usize {
        *self.config.num_challenges * (1 + *self.num_partial_products)
    }

    /// Returns the total number of lookup polynomials.
    fn num_all_lookup_polys(self: @CommonCircuitData) -> usize {
        *self.config.num_challenges * *self.num_lookup_polys
    }

    fn zs_range(self: @CommonCircuitData) -> Range<usize> {
        Range { start: 0, end: *self.config.num_challenges }
    }

    fn fri_zs_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::ZS_PARTIAL_PRODUCTS().index, self.zs_range()
        )
    }

    /// Returns polynomials that require evaluation at `zeta` and `g * zeta`.
    fn fri_next_batch_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        let mut result = self.fri_zs_polys();
        result.append_span(self.fri_lookup_polys().span());
        result
    }

    fn fri_quotient_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::QUOTIENT().index, Range { start: 0, end: self.num_quotient_polys() }
        )
    }

    /// Returns the information for lookup polynomials, i.e. the index within the oracle and the indices of the polynomials within the commitment.
    fn fri_lookup_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        FriPolynomialInfoImpl::from_range(
            PlonkOracleImpl::ZS_PARTIAL_PRODUCTS().index,
            Range {
                start: self.num_zs_partial_products_polys(),
                end: self.num_zs_partial_products_polys() + self.num_all_lookup_polys(),
            }
        )
    }

    fn num_quotient_polys(self: @CommonCircuitData) -> usize {
        *self.config.num_challenges * *self.quotient_degree_factor
    }

    fn fri_all_polys(self: @CommonCircuitData) -> Array<FriPolynomialInfo> {
        let mut result = array![];
        result.append_span(self.fri_preprocessed_polys().span());
        result.append_span(self.fri_wire_polys().span());
        result.append_span(self.fri_zs_partial_products_polys().span());
        result.append_span(self.fri_quotient_polys().span());
        result.append_span(self.fri_lookup_polys().span());

        result
    }
}

#[derive(Drop)]
pub struct VerifierOnlyCircuitData {
    pub constants_sigmas_cap: MerkleCaps,
    pub circuit_digest: HashOut,
}


#[cfg(test)]
pub mod tests {}
