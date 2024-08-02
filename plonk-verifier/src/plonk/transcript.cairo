use core::traits::TryInto;
use core::clone::Clone;
use core::traits::Into;
use core::traits::Destruct;
use core::keccak;
use core::byte_array::ByteArrayTrait;
use core::to_byte_array::{FormatAsByteArray, AppendFormattedToByteArray};
use core::fmt::{Display, Formatter, Error};
use debug::PrintTrait;
use plonk_verifier::curve::constants::{ORDER};

use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
use plonk_verifier::fields::{fq, Fq, FqIntoU256};
use plonk_verifier::traits::FieldMulShortcuts;
use plonk_verifier::plonk::utils::{convert_le_to_be, hex_to_decimal, decimal_to_byte_array};

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

        let mut buffer: ByteArray = "";

        let mut i = 0;

        while i < self.data.len() {
            println!("i {:?}", i);
            match self.data.at(i) {
                TranscriptElement::Polynomial(pt) => {
                    let x = pt.x.c0.clone();
                    let y = pt.y.c0.clone();
                    let mut x_bytes: ByteArray = decimal_to_byte_array(x);
                    let mut y_bytes: ByteArray = decimal_to_byte_array(y);
                    buffer.append(@x_bytes);
                    buffer.append(@y_bytes);
                },
                TranscriptElement::Scalar(scalar) => {
                    let s: u256 = scalar.c0.clone();
                    let mut s_bytes: ByteArray = decimal_to_byte_array(s);
                    buffer.append(@s_bytes);
                },
            };
            i += 1;
        };

        let le_value = keccak::compute_keccak_byte_array(@buffer);
        let be_value = convert_le_to_be(le_value);
        let be_u256: u256 = hex_to_decimal(be_value);

        fq(be_u256 % ORDER)
    }
}
