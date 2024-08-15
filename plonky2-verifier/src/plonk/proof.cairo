use plonky2_verifier::merkle::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::fields::goldilocks_quadratic::GoldilocksQuadratic;
use plonky2_verifier::fields::goldilocks::Goldilocks;
use plonky2_verifier::hash::poseidon::hash_no_pad;
use plonky2_verifier::hash::structure::HashOut;


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

#[generate_trait]
impl ProofWithPublicInputsImpl of ProofWithPublicInputsTrait {
    fn get_public_inputs_hash(self: @ProofWithPublicInputs) -> HashOut {
        hash_no_pad(self.public_inputs.span())
    }
}


#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::proof::{Proof};
    use plonky2_verifier::plonk::constants::sample_proof_1;
    use plonky2_verifier::hash::structure::HashOut;
    use plonky2_verifier::fields::goldilocks::{gl};
    use super::{ProofWithPublicInputsImpl};

    #[test]
    fn test_public_inputs_hash() {
        let proof = sample_proof_1::get_proof_with_public_inputs();
        let public_inputs_hash = proof.get_public_inputs_hash();
        let expected_hash = HashOut {
            elements: array![
                gl(8416658900775745054),
                gl(12574228347150446423),
                gl(9629056739760131473),
                gl(3119289788404190010)
            ]
                .span()
        };
        assert_eq!(public_inputs_hash, expected_hash);
    }

    #[test]
    fn should_load_common_circuit_data() {
        let common_data = sample_proof_1::get_common_data();
    }
}
