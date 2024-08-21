use plonk_verifier::traits::FieldOps;
use plonk_verifier::fields::{fq, Fq, fq2, Fq2, FieldUtils};
use plonk_verifier::fields::fq_generics::{TFqAdd, TFqSub, TFqMul, TFqDiv, TFqNeg, TFqPartialEq,};
use plonk_verifier::curve::{FIELD, get_field_nz};
use debug::PrintTrait;

fn ops() -> Array<Fq> {
    array![ //
    fq(256) - fq(56), fq(256) + fq(56), fq(256) * fq(56), fq(256) / fq(56), -fq(256)]
}

use plonk_verifier::curve::{sub_u, add, mul, div, neg,};

fn u256_mod_ops() -> Array<u256> {
    array![sub_u(256, 56), add(256, 56), mul(256, 56), div(256, 56), neg(256)]
}

#[test]
fn inv_one() {
    let one: Fq = FieldUtils::one();
    assert(one.inv(get_field_nz()) == one, 'incorrect inverse of one');
}
