use core::traits::Into;
use core::array::ArrayTrait;

use plonk_verifier::traits::{FieldOps as FOps, FieldShortcuts as FShort};
use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
use plonk_verifier::curve::groups::ECOperations;
use plonk_verifier::fields::{fq, Fq, fq2, Fq2};
use plonk_verifier::curve::constants::{ORDER};
use plonk_verifier::plonk::types::{PlonkProof, PlonkVerificationKey};

#[generate_trait]
impl PlonkVerifier of PVerifier {
    fn verify(
        verification_key: PlonkVerificationKey, proof: PlonkProof, publicSignals: Array<u256>
    ) -> bool {
        let mut result = true;
        result = result
            && PlonkVerifier::is_on_curve(proof.A)
            && PlonkVerifier::is_on_curve(proof.B)
            && PlonkVerifier::is_on_curve(proof.C)
            && PlonkVerifier::is_on_curve(proof.Z)
            && PlonkVerifier::is_on_curve(proof.T1)
            && PlonkVerifier::is_on_curve(proof.T2)
            && PlonkVerifier::is_on_curve(proof.T3)
            && PlonkVerifier::is_on_curve(proof.Wxi)
            && PlonkVerifier::is_on_curve(proof.Wxiw);

        result = result
            && PlonkVerifier::is_in_field(proof.eval_a)
            && PlonkVerifier::is_in_field(proof.eval_b)
            && PlonkVerifier::is_in_field(proof.eval_c)
            && PlonkVerifier::is_in_field(proof.eval_s1)
            && PlonkVerifier::is_in_field(proof.eval_s2)
            && PlonkVerifier::is_in_field(proof.eval_zw);

        result = result
            && PlonkVerifier::check_public_inputs_length(
                verification_key.nPublic, publicSignals.len().into()
            );

        result
    }

    // step 1: check if the points are on the bn254 curve
    fn is_on_curve(pt: AffineG1) -> bool {
        // bn254 curve equation: y^2 = x^3 + 3
        let x_sqr = pt.x.sqr();
        let x_cubed = x_sqr.mul(pt.x);
        let lhs = x_cubed.add(fq(3));
        let rhs = pt.y.sqr();

        rhs == lhs
    }

    // step 2: check if the field element is in the field
    fn is_in_field(num: Fq) -> bool {
        // bn254 curve field: 21888242871839275222246405745257275088548364400416034343698204186575808495617
        let field_p = fq(ORDER);

        num.c0 < field_p.c0
    }

    //step 3: check proof public inputs match the verification key 
    fn check_public_inputs_length(len_a: u256, len_b: u256) -> bool {
        len_a == len_b
    }

    // step 4: compute challenge
    fn compute_challenge() {}
    // step 6: calculate the lagrange evaluations
    fn calculate_lagrange_evaluations() {}
}


#[cfg(test)]
mod tests {
    use super::PlonkVerifier;
    use core::traits::Into;
    use core::traits::RemEq;

    use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
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
}
