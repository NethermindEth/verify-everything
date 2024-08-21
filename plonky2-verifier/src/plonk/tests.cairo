#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::proof::{Proof};
    use plonky2_verifier::plonk::test_constants::sample_proof_1;
    use plonky2_verifier::hash::structure::HashOut;
    use plonky2_verifier::fields::goldilocks::{gl, Goldilocks};
    use plonky2_verifier::fields::goldilocks_quadratic::{GoldilocksQuadratic};
    use plonky2_verifier::plonk::proof::{ProofWithPublicInputsImpl, ProofChallenges};
    use plonky2_verifier::fri::structure::{FriChallenges};

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
    #[available_gas(200000000000)]
    fn should_generate_correct_challenges() {
        let proof_with_pis = sample_proof_1::get_proof_with_public_inputs();
        let common_data = sample_proof_1::get_common_data();
        let verifier_only_data = sample_proof_1::get_verifier_only_data();

        let circuit_digest = verifier_only_data.circuit_digest;

        let public_inputs_hash = proof_with_pis.get_public_inputs_hash();
        let challenges = proof_with_pis
            .get_challenges(@public_inputs_hash, @circuit_digest, @common_data);

        let expected = ProofChallenges {
            plonk_betas: array![
                Goldilocks { inner: 2120733678132934058 },
                Goldilocks { inner: 16358318934879871511 }
            ]
                .span(),
            plonk_gammas: array![
                Goldilocks { inner: 2299061281334804352 },
                Goldilocks { inner: 15682313869372096483 }
            ]
                .span(),
            plonk_alphas: array![
                Goldilocks { inner: 17855376741508992970 },
                Goldilocks { inner: 1959246543685316574 }
            ]
                .span(),
            plonk_deltas: array![].span(),
            plonk_zeta: GoldilocksQuadratic {
                a: Goldilocks { inner: 8419238402042626796 },
                b: Goldilocks { inner: 2782223061739842093 }
            },
            fri_challenges: FriChallenges {
                fri_alpha: GoldilocksQuadratic {
                    a: Goldilocks { inner: 11288666585244694345 },
                    b: Goldilocks { inner: 4875117270188770208 }
                },
                fri_betas: array![],
                fri_pow_response: Goldilocks { inner: 161874801050727 },
                fri_query_indices: array![
                    4,
                    37,
                    11,
                    17,
                    26,
                    42,
                    19,
                    46,
                    63,
                    55,
                    57,
                    25,
                    8,
                    21,
                    6,
                    46,
                    22,
                    11,
                    33,
                    39,
                    37,
                    4,
                    59,
                    14,
                    2,
                    55,
                    17,
                    32
                ]
            }
        };

        assert_eq!(challenges, expected);
    }
}
