use plonky2_verifier::merkle::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::fields::goldilocks_quadratic::GoldilocksQuadratic;
use plonky2_verifier::fields::goldilocks::Goldilocks;

#[derive(Drop)]
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

#[derive(Drop)]
pub struct FriInitialTreeProof {
    pub evals_proofs: Span<(Span<Goldilocks>, MerkleProof)>
}

#[derive(Drop)]
pub struct FriQueryStep {
    pub evals: Span<GoldilocksQuadratic>,
    pub merkle_proof: MerkleProof
}

#[derive(Drop)]
pub struct FriQueryRound {
    pub initial_trees_proof: FriInitialTreeProof,
    pub steps: Span<FriQueryStep>,
}

#[derive(Drop)]
pub struct PolynomialCoeffs {
    pub coeffs: Span<GoldilocksQuadratic>,
}

#[derive(Drop)]
pub struct FriProof {
    pub commit_phase_merkle_caps: Span<MerkleCaps>,
    pub query_round_proofs: Span<FriQueryRound>,
    pub final_poly: PolynomialCoeffs,
    pub pow_witness: Goldilocks,
}

#[derive(Drop)]
pub struct Proof {
    pub wires_cap: MerkleCaps,
    pub plonk_zs_partial_products_cap: MerkleCaps,
    pub quotient_polys_cap: MerkleCaps,
    pub openings: OpeningSet,
    pub opening_proof: FriProof
}

#[derive(Drop)]
pub struct ProofWithPublicInputs {
    pub proof: Proof,
    pub public_inputs: Span<Goldilocks>,
}


#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::proof::{Proof};
    use plonky2_verifier::plonk::test_constants::{get_fri_query_rounds};

    #[test]
    fn test_load_sample_proof() {
        let proof = get_fri_query_rounds();
    // println!("{:?}", proof);
    }
}
