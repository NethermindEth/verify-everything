use core::array::ArrayTrait;
use core::traits::Into;
use plonk_verifier::curve::groups::{AffineG1, AffineG2};
use plonk_verifier::fields::{Fq};
use core::fmt::{Display, Formatter, Error};

// #[derive(Default, Drop)]
// pub struct Formatter {
//     /// The pending result of formatting.
//     pub buffer: ByteArray,
// }

#[derive(Copy, Drop)]
struct PlonkProof {
    A: AffineG1,
    B: AffineG1,
    C: AffineG1,
    Z: AffineG1,
    T1: AffineG1,
    T2: AffineG1,
    T3: AffineG1,
    Wxi: AffineG1,
    Wxiw: AffineG1,
    eval_a: Fq,
    eval_b: Fq,
    eval_c: Fq,
    eval_s1: Fq,
    eval_s2: Fq,
    eval_zw: Fq
}

#[derive(Copy, Drop)]
struct PlonkVerificationKey {
    n: u256,
    power: u256,
    nPublic: u256,
    nLagrange: u256,
    Qm: AffineG1,
    Qc: AffineG1,
    Ql: AffineG1,
    Qr: AffineG1,
    Qo: AffineG1,
    S1: AffineG1,
    S2: AffineG1,
    S3: AffineG1,
    X_2: AffineG2,
    w: u256
}

#[derive(Drop)]
struct PlonkChallenge {
    beta: Fq,
    gamma: Fq,
    alpha: Fq,
    xi: Fq,
    xin: Fq,
    zh: Fq,
    v: Array<Fq>,
    u: Fq
}
