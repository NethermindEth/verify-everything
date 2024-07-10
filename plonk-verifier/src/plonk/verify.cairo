use core::traits::Into;
use core::array::ArrayTrait;

use plonk_verifier::traits::{FieldOps as FOps, FieldShortcuts as FShort};
use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
use plonk_verifier::curve::groups::ECOperations;
use plonk_verifier::fields::{fq, Fq, fq2, Fq2};
use plonk_verifier::curve::constants::{ORDER};
#[generate_trait]
impl PlonkVerifier of PVerifier {
    fn verify(
        A: AffineG1,
        B: AffineG1,
        C: AffineG1,
        Z: AffineG1,
        T1: AffineG1,
        T2: AffineG1,
        T3: AffineG1,
        Wxi: AffineG1,
        Wxix: AffineG1,
        eval_a: Fq,
        eval_b: Fq,
        eval_c: Fq,
        eval_s1: Fq,
        eval_s2: Fq,
        eval_zw: Fq
    ) -> bool {
        let mut result = true;
        result = result
            && PlonkVerifier::is_on_curve(A)
            && PlonkVerifier::is_on_curve(B)
            && PlonkVerifier::is_on_curve(C)
            && PlonkVerifier::is_on_curve(Z)
            && PlonkVerifier::is_on_curve(T1)
            && PlonkVerifier::is_on_curve(T2)
            && PlonkVerifier::is_on_curve(T3)
            && PlonkVerifier::is_on_curve(Wxi)
            && PlonkVerifier::is_on_curve(Wxix);

        result = result
            && PlonkVerifier::is_in_field(eval_a)
            && PlonkVerifier::is_in_field(eval_b)
            && PlonkVerifier::is_in_field(eval_c)
            && PlonkVerifier::is_in_field(eval_s1)
            && PlonkVerifier::is_in_field(eval_s2)
            && PlonkVerifier::is_in_field(eval_zw);

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

    fn is_in_field(num: Fq) -> bool {
        // FIELD is assumed to be defined globally or passed as a parameter
        let field_p = fq(ORDER);

        num.c0 < field_p.c0
    }
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
}
