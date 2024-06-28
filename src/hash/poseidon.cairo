use core::array::ArrayTrait;
use core::array::Span;
use core::array::SpanTrait;
use core::box::BoxTrait;
use core::option::OptionTrait;
use core::to_byte_array::FormatAsByteArray;
use core::traits::Into;
use plonky2_verifier::fields::goldilocks::GoldilocksTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks, gl};
use plonky2_verifier::hash::poseidon_state::PoseidonStateArrarTrait;
use plonky2_verifier::hash::poseidon_state::{PoseidonState, PoseidonStateArray};
use plonky2_verifier::hash::poseidon_constants::{
    ALL_ROUND_CONSTANTS, HALF_N_FULL_ROUNDS, MDS_MATRIX_CIRC, MDS_MATRIX_DIAG, SPONGE_WIDTH,
    SPONGE_RATE
};

#[derive(Clone, Drop, Debug)]
pub struct PoseidonPermutation {
    pub state: PoseidonState,
}

trait Permuter {
    fn permute(ref self: PoseidonPermutation);
    fn default() -> PoseidonPermutation;
    fn new(elts: Span<Goldilocks>) -> PoseidonPermutation;
    fn set_elt(ref self: PoseidonPermutation, elt: Goldilocks, idx: usize);
    fn set_from_slice(ref self: PoseidonPermutation, slice: Span<Goldilocks>, start_idx: usize);
    fn squeeze(self: PoseidonPermutation) -> Span<Goldilocks>;
}


impl PoseidonPermuter of Permuter {
    fn default() -> PoseidonPermutation {
        PoseidonPermutation { state: PoseidonStateArray::default(), }
    }

    fn new(elts: Span<Goldilocks>) -> PoseidonPermutation {
        PoseidonPermutation { state: PoseidonStateArray::new(elts), }
    }

    fn set_elt(ref self: PoseidonPermutation, elt: Goldilocks, idx: usize) {
        self.state.set(idx, elt);
    }

    fn set_from_slice(ref self: PoseidonPermutation, slice: Span<Goldilocks>, start_idx: usize) {
        let len = slice.len();
        let mut idx = start_idx;
        loop {
            if idx >= len {
                break;
            }
            self.set_elt(*slice.at(idx), idx);
            idx += 1;
        };
    }

    fn permute(ref self: PoseidonPermutation) {
        ()
    }

    fn squeeze(self: PoseidonPermutation) -> Span<Goldilocks> {
        array![
            self.state.s0,
            self.state.s1,
            self.state.s2,
            self.state.s3,
            self.state.s4,
            self.state.s5,
            self.state.s6,
            self.state.s7,
        ]
            .span()
    }
}

#[generate_trait]
impl PoseidonTrait of Poseidon {
    fn poseidon(input: PoseidonState) -> PoseidonState {
        let mut state = input;
        let mut round_ctr = 0;

        PoseidonTrait::full_rounds(ref state, ref round_ctr);
        PoseidonTrait::partial_rounds(ref state, ref round_ctr);
        PoseidonTrait::full_rounds(ref state, ref round_ctr);

        state
    }

    fn full_rounds(ref state: PoseidonState, ref round_ctr: usize) {
        let mut i = 0;
        loop {
            if (i >= HALF_N_FULL_ROUNDS) {
                break;
            }
            PoseidonTrait::constant_layer(ref state, round_ctr);
            PoseidonTrait::sbox_layer(ref state);
            state = PoseidonTrait::mds_layer(state);
            round_ctr += 1;
            i += 1;
        }
    }

    fn constant_layer(ref state: PoseidonState, round_ctr: usize) {
        let mut i = 0;
        loop {
            if (i >= 12) {
                break;
            }

            if (i < SPONGE_WIDTH) {
                let round_constant = ALL_ROUND_CONSTANTS(i + SPONGE_WIDTH * round_ctr);
                state.set(i, state.at(i) + gl(round_constant));
            }

            i += 1;
        }
    }

    fn partial_rounds(ref state: PoseidonState, ref round_ctr: usize) {}

    fn sbox_layer(ref state: PoseidonState) {
        let mut i = 0;
        loop {
            if (i >= 12) {
                break;
            }
            if (i < SPONGE_WIDTH) {
                state.set(i, PoseidonTrait::sbox_monomial(state.at(i)));
            }

            i += 1;
        }
    }

    fn sbox_monomial(x: Goldilocks) -> Goldilocks {
        // x |--> x^7
        let x2 = x * x;
        let x4 = x2 * x2;
        let x3 = x * x2;
        x3 * x4
    }

    fn mds_layer(state_: PoseidonState) -> PoseidonState {
        let mut result = PoseidonStateArray::default();
        let mut state = ArrayTrait::<u64>::new();
        let mut i = 0;
        loop {
            if (i >= SPONGE_WIDTH) {
                break;
            }
            state.append(state_.at(i).inner);
            i += 1;
        };

        let mut r = 0;
        loop {
            if (r >= 12) {
                break;
            }

            if (r < SPONGE_WIDTH) {
                let sum: u128 = PoseidonTrait::mds_row_shf(r, state.span());
                result.set(r, GoldilocksTrait::reduce_u128(sum));
            }

            r += 1;
        };

        result
    }

    fn mds_row_shf(r: usize, v: Span<u64>) -> u128 {
        let mut res = 0;
        let mut i = 0;
        loop {
            if (i >= 12) {
                break;
            }
            if i < SPONGE_WIDTH {
                let lhs: u128 = (*v.at((i + r) % SPONGE_WIDTH)).into();
                let rhs: u128 = MDS_MATRIX_CIRC(i).into();
                res += lhs * rhs;
            }
            i += 1;
        };
        let lhs: u128 = (*v.at(r)).into();
        let rhs: u128 = MDS_MATRIX_DIAG(r).into();
        res += lhs * rhs;

        res
    }
// fn mds_partial_layer_fast(state: @PoseidonState, r: usize) -> PoseidonState {
//     let mut d_sum = 0;

//     let mut i = 0;
//     loop {
//         if (i >= 12) {
//             break;
//         }

//         if (i < SPONGE_WIDTH) {}
//     }
// }
}

pub trait PoseidonTraittmp {
    fn poseidon(state: PoseidonState) -> PoseidonState;
    fn full_rounds(ref state: PoseidonState, ref round_ctr: usize);
    fn partial_rounds(ref state: PoseidonState, ref round_ctr: usize);
    fn constant_layer();
    fn sbox_layer();
    fn mds_layer();
    fn sbox_monomial();
    fn mds_row_shf();
    fn partial_first_constant_layer();
    fn mds_partial_layer_init();
    fn mds_partial_layer_fast();
}


fn min(a: usize, b: usize) -> usize {
    if a < b {
        a
    } else {
        b
    }
}

fn max(a: usize, b: usize) -> usize {
    if a > b {
        a
    } else {
        b
    }
}

pub fn hash_n_to_m_no_pad(inputs: Span<Goldilocks>, num_outputs: usize,) -> Span<Goldilocks> {
    let mut perm = Permuter::default();

    // Absorb all input chunks.
    let mut chunk_start_idx = 0;
    loop {
        if (chunk_start_idx >= inputs.len()) {
            break;
        }
        let chunk_end_idx = min(inputs.len(), SPONGE_RATE);
        perm.set_from_slice(inputs.slice(chunk_start_idx, chunk_end_idx), 0);
        perm.permute();
        chunk_start_idx += SPONGE_RATE;
    };

    // Squeeze until we have the desired number of outputs.
    let mut outputs = array![];
    loop {
        let squeezed = perm.clone().squeeze();
        let remaining = num_outputs - outputs.len();
        outputs.append_span(squeezed.slice(0, max(remaining, squeezed.len())));

        if (outputs.len() >= num_outputs) {
            break;
        }

        perm.permute();
    };

    outputs.span()
}


#[cfg(test)]
mod tests {
    use core::to_byte_array::FormatAsByteArray;
    use core::traits::Into;
    use core::traits::RemEq;
    use super::{hash_n_to_m_no_pad, gl, PoseidonStateArray, PoseidonTrait};

    #[test]
    fn test_constant_layer() {
        let mut state = PoseidonStateArray::default();
        let expected_result = PoseidonStateArray::new(
            array![
                gl(13080132714287612933),
                gl(8594738767457295063),
                gl(12896916465481390516),
                gl(1109962092811921367),
                gl(16216730422861946898),
                gl(10137062673499593713),
                gl(15292064466732465823),
                gl(17255573294985989181),
                gl(14827154241873003558),
                gl(2846171647972703231),
                gl(16246264663680317601),
                gl(14214208087951879286)
            ]
                .span()
        );
        PoseidonTrait::constant_layer(ref state, 0);
        assert_eq!(state, expected_result);
    }

    #[test]
    fn test_sbox_monomial() {
        let x = gl(0x123456789abcdef0);
        let y = PoseidonTrait::sbox_monomial(x);
        assert_eq!(y, gl(11853639751010147186));
    }

    #[test]
    fn test_sbox_layer() {
        let mut state = PoseidonStateArray::default();
        let mut i: usize = 0;

        loop {
            if (i >= 12) {
                break;
            }
            state.set(i, gl(i.into()));
            i += 1;
        };

        let expected_result = PoseidonStateArray::new(
            array![
                gl(0),
                gl(1),
                gl(128),
                gl(2187),
                gl(16384),
                gl(78125),
                gl(279936),
                gl(823543),
                gl(2097152),
                gl(4782969),
                gl(10000000),
                gl(19487171)
            ]
                .span()
        );

        PoseidonTrait::sbox_layer(ref state);
        assert_eq!(state, expected_result);
    }

    #[test]
    fn test_mds_row_shf() {
        let v = array![0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].span();
        let r = 2;
        let res = PoseidonTrait::mds_row_shf(r, v);
        assert_eq!(res, 1360);
    }

    #[test]
    fn test_mds_layer() {
        let res = PoseidonTrait::mds_layer(
            PoseidonStateArray::new(
                array![
                    gl(0),
                    gl(1),
                    gl(128),
                    gl(2187),
                    gl(16384),
                    gl(78125),
                    gl(279936),
                    gl(823543),
                    gl(2097152),
                    gl(4782969),
                    gl(10000000),
                    gl(19487171)
                ]
                    .span()
            )
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(914231540),
                gl(1075416846),
                gl(855786472),
                gl(1020513242),
                gl(547603236),
                gl(616150402),
                gl(747427508),
                gl(449170434),
                gl(857254888),
                gl(1108558718),
                gl(656301516),
                gl(768889774)
            ]
                .span()
        );

        assert_eq!(res, expected_result);
    }

    #[test]
    fn test_full_rounds() {
        let mut input = PoseidonStateArray::new(
            array![
                gl(914231540),
                gl(1075416846),
                gl(855786472),
                gl(1020513242),
                gl(547603236),
                gl(616150402),
                gl(747427508),
                gl(449170434),
                gl(857254888),
                gl(1108558718),
                gl(656301516),
                gl(768889774)
            ]
                .span()
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(1158591658132417480),
                gl(137247361791616024),
                gl(3218529736599695278),
                gl(3925622091019036698),
                gl(4635706851757400233),
                gl(17703058331371986941),
                gl(13692720122490665532),
                gl(2541895476654820342),
                gl(7339931419297205742),
                gl(14123711498847824253),
                gl(7605504232204308633),
                gl(13111474160528884292)
            ]
                .span()
        );

        let mut round_ctr = 0;
        PoseidonTrait::full_rounds(ref input, ref round_ctr);
        assert_eq!(input, expected_result);
        assert_eq!(round_ctr, 4);
    }

    #[test]
    fn test_2d_array() {
        let d2 = array![array![0, 1, 2], array![2, 3, 5]];

        let el = *((d2.get(1).unwrap().unbox()).get(0).unwrap().unbox());

        println!("{:?}", el);
    }
}
