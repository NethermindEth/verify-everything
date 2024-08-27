#[cfg(test)]
mod plonk_tests {
    use core::clone::Clone;
    use plonk_verifier::plonk::constants;
    use plonk_verifier::plonk::types::{
        PlonkProof, PlonkVerificationKey, PlonkChallenge, PlonkChallengePartialEq
    };
    use plonk_verifier::plonk::verify::{PlonkVerifier};
    use core::traits::Into;
    use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2, Fq, Fq2};

    #[test]
    #[available_gas(100000000000)]
    fn test_plonk_verify() {
        // verification PlonkVerificationKey
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
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
    use plonk_verifier::fields::{fq};

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
    fn test_compute_challenges() {
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };

        // proof
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };

        //public_signals
        let public_signals = constants::public_inputs();

        let challenges = PlonkVerifier::compute_challenges(
            verification_key.clone(), proof.clone(), public_signals.clone()
        );
        let correct_challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(0),
            zh: fq(0),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };

        let is_equal: bool = PlonkChallengePartialEq::eq(@challenges, @correct_challenges);

        assert_eq!(is_equal, true);
    }

    #[test]
    fn test_compute_lagrange_evaluations() {
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };
        let mut challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(0),
            zh: fq(0),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };
        let (L, challenges) = PlonkVerifier::compute_lagrange_evaluations(
            verification_key, challenges
        );
        let correct_L = array![
            fq(0),
            fq(2620616904154172175670395853552055689556084771717235903725482226645091308782),
            fq(9735872642513449311527546906861943889880061684478058520701947259343550999827),
            fq(8327986554861251626971745666386010873552460747759282479133954378286727378410),
            fq(4022337429609156333024873048706819958201086574374594171651602119736297244553),
            fq(6617265984905210439143759470664564048122583210514619596354035502195742709385),
        ];
        assert_eq!(
            challenges.xin,
            fq(2547969369229319030019457190033843677010987911599058423863006450250883277211)
        );
        assert_eq!(
            challenges.zh,
            fq(2547969369229319030019457190033843677010987911599058423863006450250883277210)
        );
        assert_eq!(L, correct_L);
    }

    #[test]
    fn test_compute_PI() {
        let public_signals = constants::public_inputs();
        let L = array![
            fq(0),
            fq(2620616904154172175670395853552055689556084771717235903725482226645091308782),
            fq(9735872642513449311527546906861943889880061684478058520701947259343550999827),
            fq(8327986554861251626971745666386010873552460747759282479133954378286727378410),
            fq(4022337429609156333024873048706819958201086574374594171651602119736297244553),
            fq(6617265984905210439143759470664564048122583210514619596354035502195742709385),
        ];
        let PI = PlonkVerifier::compute_PI(public_signals, L);
        let correct_PI: u256 =
            18271457399299900228442257502287788641966159684441642978038700334889779304449;
        assert_eq!(fq(correct_PI), PI);
    }

    #[test]
    fn test_compute_R0() {
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };

        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };

        let public_signals = constants::public_inputs();
        let challenges = PlonkVerifier::compute_challenges(
            verification_key.clone(), proof.clone(), public_signals.clone()
        );
        let L = array![
            fq(0),
            fq(2620616904154172175670395853552055689556084771717235903725482226645091308782),
            fq(9735872642513449311527546906861943889880061684478058520701947259343550999827),
            fq(8327986554861251626971745666386010873552460747759282479133954378286727378410),
            fq(4022337429609156333024873048706819958201086574374594171651602119736297244553),
            fq(6617265984905210439143759470664564048122583210514619596354035502195742709385),
        ];
        let PI = PlonkVerifier::compute_PI(public_signals.clone(), L.clone());
        let R0 = PlonkVerifier::compute_R0(proof, challenges, PI, L[1].clone());

        let correct_R0: u256 =
            8252012205077960742641393316361079931166529015625841574934366119104137152715;
        assert_eq!(fq(correct_R0), R0);
    }

    #[test]
    fn test_compute_D() {
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };
        let challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(2547969369229319030019457190033843677010987911599058423863006450250883277211),
            zh: fq(2547969369229319030019457190033843677010987911599058423863006450250883277210),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };
        let L1 = fq(2620616904154172175670395853552055689556084771717235903725482226645091308782);
        let D = PlonkVerifier::compute_D(proof, challenges, verification_key, L1);
        let corret_D = g1(
            4333398450220542935061332802082369181528242679087535767638817155055555907729,
            3001452470579370622125939372942669046487921723785465821088780020440992474494
        );
        assert_eq!(D.x, corret_D.x);
        assert_eq!(D.y, corret_D.y);
    }

    #[test]
    fn test_compute_F() {
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };
        let challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(2547969369229319030019457190033843677010987911599058423863006450250883277211),
            zh: fq(2547969369229319030019457190033843677010987911599058423863006450250883277210),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };
        let D = g1(
            4333398450220542935061332802082369181528242679087535767638817155055555907729,
            3001452470579370622125939372942669046487921723785465821088780020440992474494
        );
        let F = PlonkVerifier::compute_F(proof, challenges, verification_key, D);
        let correct_F = g1(
            2447957664398607938229566909991195557288608349864545209476580844025113917745,
            16981442144394521581137981015380711983763128730701172250766417640481995742343
        );
        assert_eq!(F.x, correct_F.x);
        assert_eq!(F.y, correct_F.y);
    }

    #[test]
    fn test_compute_E() {
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };
        let challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(2547969369229319030019457190033843677010987911599058423863006450250883277211),
            zh: fq(2547969369229319030019457190033843677010987911599058423863006450250883277210),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };

        let R0: u256 = 8252012205077960742641393316361079931166529015625841574934366119104137152715;
        let E = PlonkVerifier::compute_E(proof, challenges, fq(R0));
        let correct_E = g1(
            2484568790068257088204458404505761583129899393337173775535121851653226285099,
            6454403560011284872933736696278881925473069516668053066370404348177163484123
        );
        assert_eq!(E.x, correct_E.x);
        assert_eq!(E.y, correct_E.y);
    }

    #[test]
    fn test_valid_pairing() {
        let (A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw) =
            constants::proof();
        let proof = PlonkProof {
            A, B, C, Z, T1, T2, T3, Wxi, Wxiw, eval_a, eval_b, eval_c, eval_s1, eval_s2, eval_zw
        };
        let challenges: PlonkChallenge = PlonkChallenge {
            beta: fq(14498736666711970908375456476345180774162405747758964362513385423508335735322),
            gamma: fq(
                12473575158495020584075331747768007427040808349100262643951655593347205212105
            ),
            alpha: fq(1638659385023515386554508818708523991148437210157968065970684882752976352387),
            xi: fq(11882213808513143293994894265765176245869305285611379364593291279901519522928),
            xin: fq(2547969369229319030019457190033843677010987911599058423863006450250883277211),
            zh: fq(2547969369229319030019457190033843677010987911599058423863006450250883277210),
            v1: fq(15525246157134916236476400018821255884822413269025828374216029504649227137669),
            v2: fq(21132627888087099743804979172433285392556642515445679407925856696706183143931),
            v3: fq(14811188092632618134958606395686769465009218042016000324383312979839817536369),
            v4: fq(4108746516280855064593980008751272222578296515181456478736767522256005393754),
            v5: fq(21273923665773393693442929292304958706950228002872333898227188355663509830744),
            u: fq(6089190548497707896050173528768502095987431640910795526240399704164855396906)
        };
        let (n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
            constants::verification_key();
        let verification_key = PlonkVerificationKey {
            n, power, k1, k2, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
        };
        let E = g1(
            2484568790068257088204458404505761583129899393337173775535121851653226285099,
            6454403560011284872933736696278881925473069516668053066370404348177163484123
        );
        let F = g1(
            2447957664398607938229566909991195557288608349864545209476580844025113917745,
            16981442144394521581137981015380711983763128730701172250766417640481995742343
        );
        let valid = PlonkVerifier::valid_pairing(proof, challenges, verification_key, E, F);
        assert_eq!(valid, true);
    }

    // corelib keccak hash test
    #[test]
    fn test_byte_array() {
        let mut ba = @"hello-world";
        let byte_array_hash_decimal = keccak::compute_keccak_byte_array(ba);

        assert(
            byte_array_hash_decimal == 98480953116143538305566652828570234404584964502089063494794966986746485349332,
            'keccak256 hash correct'
        );
    }

    // test utility functions
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
