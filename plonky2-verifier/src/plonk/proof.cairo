use plonky2_verifier::merkle::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::fields::goldilocks_quadratic::GoldilocksQuadratic;
use plonky2_verifier::fields::goldilocks::Goldilocks;

#[derive(Drop, Debug)]
pub struct OpeningSet {
    pub constants: Array<GoldilocksQuadratic>,
    pub plonk_sigmas: Array<GoldilocksQuadratic>,
    pub wires: Array<GoldilocksQuadratic>,
    pub plonk_zs: Array<GoldilocksQuadratic>,
    pub plonk_zs_next: Array<GoldilocksQuadratic>,
    pub partial_products: Array<GoldilocksQuadratic>,
    pub quotient_polys: Array<GoldilocksQuadratic>,
    pub lookup_zs: Array<GoldilocksQuadratic>,
    pub lookup_zs_next: Array<GoldilocksQuadratic>,
}

#[derive(Drop, Debug)]
pub struct FriInitialTreeProof {
    pub evals_proofs: Array<(Array<Goldilocks>, MerkleProof)>
}

#[derive(Drop, Debug)]
pub struct FriQueryStep {
    pub evals: Array<GoldilocksQuadratic>,
    pub merkle_proof: MerkleProof
}

#[derive(Drop, Debug)]
pub struct FriQueryRound {
    pub initial_trees_proof: FriInitialTreeProof,
    pub steps: Array<FriQueryStep>,
}

#[derive(Drop, Debug)]
pub struct PolynomialCoeffs {
    pub coeffs: Array<GoldilocksQuadratic>,
}

#[derive(Drop, Debug)]
pub struct FriProof {
    pub commit_phase_merkle_caps: Array<MerkleCaps>,
    pub query_round_proofs: Array<FriQueryRound>,
    pub final_poly: PolynomialCoeffs,
    pub pow_witness: Goldilocks,
}

#[derive(Drop, Debug)]
pub struct Proof {
    pub wires_cap: MerkleCaps,
    pub plonk_zs_partial_products_cap: MerkleCaps,
    pub quotient_polys_cap: MerkleCaps,
    pub openings: OpeningSet,
    pub opening_proof: FriProof
}

#[derive(Drop, Debug)]
pub struct ProofWithPublicInputs {
    pub proof: Proof,
    pub public_inputs: Array<Goldilocks>,
}


#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::proof::{Proof};
    use plonky2_verifier::plonk::test_constants::{get_proof};

    #[test]
    fn test_load_sample_proof() {
        let proof = get_proof();
        println!("{:?}", proof);
    // println!("{:?}", proof);
    }
}
