#[cfg(test)]
mod plonk_tests {
    use plonk_verifier::plonk::constants;
    use plonk_verifier::plonk::types::{PlonkProof, PlonkVerificationKey};
    use plonk_verifier::plonk::verify::{PlonkVerifier};
    use core::traits::Into;
    use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};

    #[test]
    fn test_plonk_verify() {
        // verification PlonkVerificationKey
        let (n, power, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };

        // proof
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };

        //public_signals
        let public_signals = constants::public_inputs();

        let verified = PlonkVerifier::verify(verification_key, proof, public_signals);
        assert(verified, 'verification failed');
    }

    #[test]
    fn test_is_on_curve() {
        let pt_on_curve = g1(
            4693417943536520268746058560989260808135478372449023987176805259899316401080,
            8186764010206899711756657704517859444555824539207093839904632766037261603989
        );
        let pt_not_on_curve = g1(
            4693417943536520268746058560989260808135478372449023987176805259899316401080,
            8186764010206899711756657704517859444555824539207093839904632766037261603987
        );
        assert_eq!(PlonkVerifier::is_on_curve(pt_on_curve), true);
        assert_eq!(PlonkVerifier::is_on_curve(pt_not_on_curve), false);
    }

    use plonk_verifier::curve::constants::{ORDER};
    use plonk_verifier::fields::{fq, Fq};

    #[test]
    fn test_is_in_field() {
        let num_in_field = fq(
            12414878641105079363695639132995965092423960984837736008191365473346709965275
        );
        let num_not_in_field = fq(
            31888242871839275222246405745257275088548364400416034343698204186575808495617
        );
        assert_eq!(PlonkVerifier::is_in_field(num_in_field), true);
        assert_eq!(PlonkVerifier::is_in_field(num_not_in_field), false);
    }

    #[test]
    fn test_check_public_inputs_length() {
        let len_a = 5;
        let len_b = 5;
        let len_c = 6;

        assert_eq!(PlonkVerifier::check_public_inputs_length(len_a, len_b), true);
        assert_eq!(PlonkVerifier::check_public_inputs_length(len_a, len_c), false);
    }

    #[test]
    fn test_byte_array() {
        let mut ba = @"hello-world";
        let byte_array_hash_decimal = keccak::compute_keccak_byte_array(ba);

        assert(
            byte_array_hash_decimal == 98480953116143538305566652828570234404584964502089063494794966986746485349332,
            'keccak256 hash correct'
        );
    }
}
