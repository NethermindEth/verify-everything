use plonky2_verifier::merkle::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::fields::goldilocks_quadratic::GoldilocksQuadratic;
use plonky2_verifier::fields::goldilocks::Goldilocks;

pub struct OpeningSet {
    pub constants: Span<GoldilocksQuadratic>,
    pub plonk_sigmas: Span<GoldilocksQuadratic>,
    pub wires: Span<GoldilocksQuadratic>,
    pub plonk_zs: Span<GoldilocksQuadratic>,
    pub plonk_zs_next: Span<GoldilocksQuadratic>,
    pub partial_products: Span<GoldilocksQuadratic>,
    pub quotient_polys: Span<GoldilocksQuadratic>,
    pub lookup_zs: Span<GoldilocksQuadratic>,
    pub lookup_zs_next: Span<GoldilocksQuadratic>,
}

pub struct FriInitialTreeProof {
    pub evals_proofs: Span<(Span<Goldilocks>, MerkleProof)>
}

pub struct FriQueryStep {
    pub evals: Span<GoldilocksQuadratic>,
    pub merkle_proof: MerkleProof
}

pub struct FriQueryRound {
    pub initial_trees_proof: FriInitialTreeProof,
    pub steps: Span<FriQueryStep>,
}

pub struct PolynomialCoeffs {
    pub coeffs: Span<GoldilocksQuadratic>,
}

pub struct FriProof {
    pub commit_phase_merkle_caps: Span<MerkleCaps>,
    pub query_round_proofs: Span<FriQueryRound>,
    pub final_poly: PolynomialCoeffs,
    pub pow_witness: Goldilocks,
}

pub struct Proof {
    pub wires_cap: MerkleCaps,
    pub plonk_zs_partial_products_cap: MerkleCaps,
    pub quotient_polys_cap: MerkleCaps,
    pub openings: OpeningSet,
    pub opening_proof: FriProof
}


pub struct ProofWithPublicInputs {
    pub proof: Proof,
    pub public_inputs: Span<Goldilocks>,
}
