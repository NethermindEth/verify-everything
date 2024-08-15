#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::proof::{Proof};
    use plonky2_verifier::plonk::constants::sample_proof_1;
    use plonky2_verifier::hash::structure::HashOut;
    use plonky2_verifier::fields::goldilocks::{gl};
    use plonky2_verifier::plonk::proof::{ProofWithPublicInputsImpl};

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
    fn should_load_circuit_data() {
        let _common_data = sample_proof_1::get_common_data();
        let _verifier_only_data = sample_proof_1::get_verifier_only_data();
    }

    #[test]
    fn should_generate_correct_challenges() {
        let proof_with_pis = sample_proof_1::get_proof_with_public_inputs();
        let common_data = sample_proof_1::get_common_data();
        let verifier_only_data = sample_proof_1::get_verifier_only_data();

        let circuit_digest = verifier_only_data.circuit_digest;

        let public_inputs_hash = proof_with_pis.get_public_inputs_hash();
        let challenges = proof_with_pis
            .get_challenges(@public_inputs_hash, @circuit_digest, @common_data);

        println!("challenges: {:?}", challenges);
    }
}
