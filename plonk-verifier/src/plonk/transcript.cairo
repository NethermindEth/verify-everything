use core::clone::Clone;
use core::traits::Into;
use plonk_verifier::traits::FieldMulShortcuts;
use core::array::SpanTrait;
use core::array::ArrayTrait;
use core::traits::Destruct;
use core::keccak;
use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
use plonk_verifier::fields::{fq, Fq, fq2, Fq2, FqIntoU256};

#[derive(Drop)]
pub struct PlonkTranscript {
    data: Array<TranscriptElement<AffineG1, Fq>>
}

#[derive(Drop)]
enum TranscriptElement<AffineG1, Fq> {
    Polynomial: AffineG1,
    Scalar: Fq,
}

#[derive(Drop)]
trait Keccak256Transcript<T> {
    fn new() -> T;
    fn add_pol_commitment(ref self: T, polynomial_commitment: AffineG1);
    fn add_scalar(ref self: T, scalar: Fq);
    fn get_challenge(self: T) -> Fq;
}

#[derive(Drop)]
impl Transcript of Keccak256Transcript<PlonkTranscript> {
    fn new() -> PlonkTranscript {
        PlonkTranscript { data: ArrayTrait::new() }
    }
    fn add_pol_commitment(ref self: PlonkTranscript, polynomial_commitment: AffineG1) {
        self.data.append(TranscriptElement::Polynomial(polynomial_commitment));
    }

    fn add_scalar(ref self: PlonkTranscript, scalar: Fq) {
        self.data.append(TranscriptElement::Scalar(scalar));
    }

    fn get_challenge(mut self: PlonkTranscript) -> Fq {
        if 0 == self.data.len() {
            panic!("Keccak256Transcript: No data to generate a transcript");
        }

        let mut buffer = ArrayTrait::<u256>::new();
        let mut i = 0;
        while i < self
            .data
            .len() {
                match self.data.at(i) {
                    TranscriptElement::Polynomial(pt) => {
                        let x = pt.x;
                        let y = pt.y;
                        buffer.append(FqIntoU256::into(x.clone()));
                        buffer.append(FqIntoU256::into(y.clone()));
                    },
                    TranscriptElement::Scalar(scalar) => {
                        buffer.append(FqIntoU256::into(scalar.clone()));
                    },
                };
                i += 1;
            };

        let value = keccak::keccak_u256s_be_inputs(buffer.span());
        fq(value)
    }
}
