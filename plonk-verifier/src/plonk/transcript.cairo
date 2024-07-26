use core::clone::Clone;
use core::traits::Into;
use core::array::SpanTrait;
// use core::array::ArrayTrait;
use core::traits::Destruct;
use core::keccak;
use core::byte_array::ByteArrayTrait;
use core::to_byte_array::{FormatAsByteArray, AppendFormattedToByteArray};
use core::fmt::{Display, Formatter, Error};
use debug::PrintTrait;

use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2};
use plonk_verifier::fields::{fq, Fq, fq2, Fq2, FqIntoU256};
use plonk_verifier::traits::FieldMulShortcuts;

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
            let hex_base: NonZero<u256> = 16_u256.try_into().unwrap();
            match self.data.at(i) {
                TranscriptElement::Polynomial(pt) => {
                    let x = pt.x.c0;
                    let y = pt.y.c0;
                    let u256x = x.clone();
                    let u256y = y.clone();

                    let ba_x = u256x.format_as_byte_array(hex_base);
                    let ba_y = u256y.format_as_byte_array(hex_base);
                    buffer.append(@ba_x);
                    buffer.append(@ba_y);
                },
                TranscriptElement::Scalar(scalar) => {
                    let s = scalar.c0.clone();
                    let ba_s = s.format_as_byte_array(hex_base);
                    buffer.append(@ba_s);
                },
                // println!("buffer: {:?}", @buffer);
            };
            i += 1;
        };

        let value = keccak::compute_keccak_byte_array(@buffer);
        fq(value)
    }
}
