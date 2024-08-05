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

    use plonk_verifier::plonk::utils::{
        convert_le_to_be, hex_to_decimal, decimal_to_byte_array, left_padding_32_bytes, ascii_to_dec
    };
    #[test]
    fn test_hex_to_decimal() {
        let test_hex_1: ByteArray =
            "1a45183d6c56cf5364935635b48815116ad40d9382a41e525d9784b4916c2c70";
        let dec_1 = hex_to_decimal(test_hex_1);
        assert_eq!(
            dec_1, 11882213808513143293994894265765176245869305285611379364593291279901519522928
        );

        let test_hex_2: ByteArray =
            "acc0b671a0e5c50307b930cfd05ed26ff6db6c6aa81ac7f8a1ed11b077a2a7cc";
        let dec_2 = hex_to_decimal(test_hex_2);
        assert_eq!(
            dec_2, 78138303774012846250814548983539832692685901550348365675046268153074630698956
        );

        let test_hex_3: ByteArray = "ff";
        let dec_3 = hex_to_decimal(test_hex_3);
        assert_eq!(dec_3, 255);
    }

    #[test]
    fn test_convert_le_to_be() {
        let test_1: u256 =
            61490746474045761767661087867430693677409928396669494327352779807704464432003;
        let le_1 = convert_le_to_be(test_1);
        assert_eq!(le_1, "831b973f210f2ca7224752808be5c58fa20f316b67823942965aa4517687f287");

        let test_2: u256 =
            19101300766783147186443130233662574138172230046365805365368327481934084863501;
        let le_2 = convert_le_to_be(test_2);
        assert_eq!(le_2, "0d765c165a19aa287707be08978a793366584fc2d5553e76957a1fe7fef33a2a");
    }

    #[test]
    fn test_left_padding_32_bytes() {
        let test_1: ByteArray = "hello";
        let padded_1 = left_padding_32_bytes(test_1);
        assert_eq!(padded_1, "00000000000000000000000000000000000000000000000000000000000hello");

        let test_2: ByteArray = "2c6c91b484975d521ea482930dd46a111588b43556936453cf566c3d18451a";
        let padded_2 = left_padding_32_bytes(test_2);
        assert_eq!(padded_2, "002c6c91b484975d521ea482930dd46a111588b43556936453cf566c3d18451a");
    }

    #[test]
    fn test_ascii_to_dec() {
        let test_1: u8 = 97;
        let dec_1 = ascii_to_dec(test_1);
        assert_eq!(dec_1, 10);

        let test_2: u8 = 48;
        let dec_2 = ascii_to_dec(test_2);
        assert_eq!(dec_2, 0);

        let test_3: u8 = 102;
        let dec_3 = ascii_to_dec(test_3);
        assert_eq!(dec_3, 15);
    }
}
