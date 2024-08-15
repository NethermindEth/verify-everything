use plonky2_verifier::fri::structure::{FriParams, FriConfig};
use plonky2_verifier::hash::structure::HashOut;
use plonky2_verifier::fields::goldilocks::Goldilocks;
use plonky2_verifier::hash::merkle_caps::MerkleCaps;

#[derive(Drop)]
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

#[derive(Drop)]
pub struct Range<Idx> {
    pub start: Idx,
    pub end: Idx,
}

#[derive(Drop)]
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

#[derive(Drop)]
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
}

#[derive(Drop)]
pub struct VerifierOnlyCircuitData {
    pub constants_sigmas_cap: MerkleCaps,
    pub circuit_digest: HashOut,
}
