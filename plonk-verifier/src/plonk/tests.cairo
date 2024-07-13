use plonk_verifier::plonk::constants;
use plonk_verifier::plonk::types::{PlonkProof, PlonkVerificationKey};
use plonk_verifier::plonk::verify::{PlonkVerifier};

#[test]
#[available_gas(20000000000)]
fn plonk_verify() {
    // verification PlonkVerificationKey
    let (n, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w) =
        constants::verification_key();
    let verification_key = PlonkVerificationKey {
        n, nPublic, nLagrange, Qm, Ql, Qr, Qo, Qc, S1, S2, S3, X_2, w
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
