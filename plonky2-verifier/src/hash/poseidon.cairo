use core::array::ArrayTrait;
use core::array::Span;
use core::array::SpanTrait;
use core::option::OptionTrait;
use core::to_byte_array::FormatAsByteArray;
use core::traits::Into;
use plonky2_verifier::fields::goldilocks::GoldilocksTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks, gl};
use plonky2_verifier::hash::poseidon_state::PoseidonStateArrarTrait;
use plonky2_verifier::hash::poseidon_state::{
    PoseidonState, PoseidonStateArray, HashOut, HashOutImpl
};

use core::cmp::{min, max};

use plonky2_verifier::hash::poseidon_constants::{
    ALL_ROUND_CONSTANTS, HALF_N_FULL_ROUNDS, MDS_MATRIX_CIRC, MDS_MATRIX_DIAG, SPONGE_WIDTH,
    SPONGE_RATE, FAST_PARTIAL_ROUND_VS, FAST_PARTIAL_ROUND_W_HATS,
    FAST_PARTIAL_FIRST_ROUND_CONSTANT, FAST_PARTIAL_ROUND_INITIAL_MATRIX, N_PARTIAL_ROUNDS,
    FAST_PARTIAL_ROUND_CONSTANTS
};

#[derive(Clone, Drop, Debug)]
pub struct PoseidonPermutation {
    pub state: PoseidonState,
}

#[generate_trait]
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
        let mut idx = 0;
        loop {
            if idx >= len {
                break;
            }
            self.set_elt(*slice.at(idx), idx + start_idx);
            idx += 1;
        };
    }

    fn permute(ref self: PoseidonPermutation) {
        self.state = PoseidonTrait::poseidon(self.state);
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

    fn partial_rounds(ref state: PoseidonState, ref round_ctr: usize) {
        PoseidonTrait::partial_first_constant_layer(ref state);
        state = PoseidonTrait::mds_partial_layer_init(@state);

        let mut i = 0;
        loop {
            if (i >= N_PARTIAL_ROUNDS) {
                break;
            }
            state.set(0, PoseidonTrait::sbox_monomial(state.at(0)));
            state.set(0, state.at(0) + gl(FAST_PARTIAL_ROUND_CONSTANTS(i)));
            state = PoseidonTrait::mds_partial_layer_fast(@state, i);

            i += 1;
        };
        round_ctr += N_PARTIAL_ROUNDS;
    }

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

    fn partial_first_constant_layer(ref state: PoseidonState,) {
        let mut i = 0;
        loop {
            if (i >= 12) {
                break;
            }

            if (i < SPONGE_WIDTH) {
                state.set(i, state.at(i) + gl(FAST_PARTIAL_FIRST_ROUND_CONSTANT(i)));
            }

            i += 1;
        }
    }

    fn mds_partial_layer_fast(state: @PoseidonState, r: usize) -> PoseidonState {
        let mut d_sum = 0;

        let mut i = 1;
        loop {
            if (i >= 12) {
                break;
            }

            if (i < SPONGE_WIDTH) {
                let t: u256 = FAST_PARTIAL_ROUND_W_HATS(r, i - 1).into();
                let si: u256 = state.at(i).inner.into();
                d_sum += t * si;
            }

            i += 1;
        };

        let s0: u256 = state.at(0).inner.into();
        let mds0to0: u256 = (MDS_MATRIX_CIRC(0) + MDS_MATRIX_DIAG(0)).into();
        d_sum += mds0to0 * s0;
        let d = GoldilocksTrait::reduce_u256(d_sum);

        let mut result = PoseidonStateArray::default();
        result.set(0, d);

        i = 1;
        loop {
            if (i >= 12) {
                break;
            }

            if (i < SPONGE_WIDTH) {
                let t = GoldilocksTrait::reduce_u64(FAST_PARTIAL_ROUND_VS(r, i - 1));
                let acc = state.at(i) + state.at(0) * t;
                result.set(i, acc);
            }

            i += 1;
        };

        result
    }

    fn mds_partial_layer_init(state: @PoseidonState,) -> PoseidonState {
        let mut result = PoseidonStateArray::default();
        result.set(0, state.at(0));

        let mut r = 1;
        loop {
            if (r >= 12) {
                break;
            }
            if (r < SPONGE_WIDTH) {
                let mut c = 1;
                loop {
                    if (c >= 12) {
                        break;
                    }

                    let t = gl(FAST_PARTIAL_ROUND_INITIAL_MATRIX(r - 1, c - 1));
                    result.set(c, result.at(c) + state.at(r) * t);

                    c += 1;
                };
                r += 1;
            }
        };

        result
    }
}

pub fn hash_n_to_m_no_pad(inputs: Span<Goldilocks>, num_outputs: usize) -> Span<Goldilocks> {
    let mut perm = Permuter::default();

    // Absorb all input chunks.
    let mut chunk_start_idx = 0;
    loop {
        if (chunk_start_idx >= inputs.len()) {
            break;
        }
        let len = min(inputs.len() - chunk_start_idx, SPONGE_RATE);
        let chunk = inputs.slice(chunk_start_idx, len);
        perm.set_from_slice(chunk, 0);
        perm.permute();
        chunk_start_idx += SPONGE_RATE;
    };

    // Squeeze until we have the desired number of outputs.
    let mut outputs = array![];
    loop {
        let squeezed = perm.clone().squeeze();
        let remaining = num_outputs - outputs.len();
        outputs.append_span(squeezed.slice(0, min(squeezed.len(), remaining)));

        if (outputs.len() == num_outputs) {
            break;
        }

        perm.permute();
    };

    outputs.span()
}

pub fn hash_two_to_one(x: HashOut, y: HashOut) -> HashOut {
    let mut perm = Permuter::default();
    perm.set_from_slice(x.elemets, 0);
    perm.set_from_slice(y.elemets, 4);

    perm.permute();

    HashOutImpl::new(perm.squeeze().slice(0, 4))
}


#[cfg(test)]
mod tests {
    use core::to_byte_array::FormatAsByteArray;
    use core::traits::Into;
    use core::traits::RemEq;
    use super::{
        hash_n_to_m_no_pad, gl, PoseidonStateArray, PoseidonTrait, hash_two_to_one, HashOut
    };
    use plonky2_verifier::hash::poseidon_state::{PoseidonState, HashOutImpl};

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
    fn test_partial_layer_fast() {
        let state = PoseidonStateArray::new(
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

        let expected_result = PoseidonStateArray::new(
            array![
                gl(14539304406632456965),
                gl(6017649415082732836),
                gl(14032894387583547173),
                gl(17921459405982495266),
                gl(17827477559628505537),
                gl(6260806333151500256),
                gl(16941299559327036255),
                gl(9834758367186550594),
                gl(12377722660802145351),
                gl(4233063172349874047),
                gl(3974876817075589809),
                gl(11859251607231694018)
            ]
                .span()
        );

        let res = PoseidonTrait::mds_partial_layer_fast(@state, 4);
        assert_eq!(res, expected_result);
    }

    #[test]
    fn test_partial_layer_constant_layer() {
        let mut input = PoseidonStateArray::new(
            array![
                gl(14539304406632456965),
                gl(6017649415082732836),
                gl(14032894387583547173),
                gl(17921459405982495266),
                gl(17827477559628505537),
                gl(6260806333151500256),
                gl(16941299559327036255),
                gl(9834758367186550594),
                gl(12377722660802145351),
                gl(4233063172349874047),
                gl(3974876817075589809),
                gl(11859251607231694018)
            ]
                .span()
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(471176906308802316),
                gl(4401980321970947348),
                gl(13060993412745816787),
                gl(14629343519671912171),
                gl(13600602154763036659),
                gl(16770127937542517218),
                gl(16040459091382950361),
                gl(13108387677668497835),
                gl(2293865805537723623),
                gl(11820824528557420228),
                gl(10933900285832905721),
                gl(7478455332676441037)
            ]
                .span()
        );

        PoseidonTrait::partial_first_constant_layer(ref input);
        assert_eq!(input, expected_result);
    }

    #[test]
    fn test_mds_partial_layer_init() {
        let input = PoseidonStateArray::new(
            array![
                gl(471176906308802316),
                gl(4401980321970947348),
                gl(13060993412745816787),
                gl(14629343519671912171),
                gl(13600602154763036659),
                gl(16770127937542517218),
                gl(16040459091382950361),
                gl(13108387677668497835),
                gl(2293865805537723623),
                gl(11820824528557420228),
                gl(10933900285832905721),
                gl(7478455332676441037)
            ]
                .span()
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(471176906308802316),
                gl(16173844670904919432),
                gl(8473571493109560994),
                gl(4403892705227851317),
                gl(8220676350090008533),
                gl(4795979071641533038),
                gl(16167936039551802543),
                gl(3337707538344096463),
                gl(10722756388422820587),
                gl(2273429771117018807),
                gl(8038654616179125948),
                gl(3316660945825807549)
            ]
                .span()
        );

        let res = PoseidonTrait::mds_partial_layer_init(@input);
        assert_eq!(res, expected_result);
    }

    #[test]
    fn test_partial_rounds() {
        let mut input = PoseidonStateArray::new(
            array![
                gl(14539304406632456965),
                gl(6017649415082732836),
                gl(14032894387583547173),
                gl(17921459405982495266),
                gl(17827477559628505537),
                gl(6260806333151500256),
                gl(16941299559327036255),
                gl(9834758367186550594),
                gl(12377722660802145351),
                gl(4233063172349874047),
                gl(3974876817075589809),
                gl(11859251607231694018)
            ]
                .span()
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(9000433109817942196),
                gl(8661098813717630969),
                gl(16539011928473401197),
                gl(8762226977564441021),
                gl(1854761156979052751),
                gl(2575699913520493950),
                gl(15561758614875811622),
                gl(6273435989783426051),
                gl(1129977394388384384),
                gl(4031571319603242564),
                gl(7300860538066292886),
                gl(12226188138814157204)
            ]
                .span()
        );

        let mut round_ctr = 0;
        PoseidonTrait::partial_rounds(ref input, ref round_ctr);
        assert_eq!(input, expected_result);
        assert_eq!(round_ctr, 22);
    }

    #[test]
    fn test_poseidon() {
        let input = PoseidonStateArray::new(
            array![
                gl(0x8ccbbbea4fe5d2b7),
                gl(0xc2af59ee9ec49970),
                gl(0x90f7e1a9e658446a),
                gl(0xdcc0630a3ab8b1b8),
                gl(0x7ff8256bca20588c),
                gl(0x5d99a7ca0c44ecfb),
                gl(0x48452b17a70fbee3),
                gl(0xeb09d654690b6c88),
                gl(0x4a55d3a39c676a88),
                gl(0xc0407a38d2285139),
                gl(0xa234bac9356386d1),
                gl(0xe1633f2bad98a52f),
            ]
                .span()
        );

        let expected_result = PoseidonStateArray::new(
            array![
                gl(0xa89280105650c4ec),
                gl(0xab542d53860d12ed),
                gl(0x5704148e9ccab94f),
                gl(0xd3a826d4b62da9f5),
                gl(0x8a7a6ca87892574f),
                gl(0xc7017e1cad1a674e),
                gl(0x1f06668922318e34),
                gl(0xa3b203bc8102676f),
                gl(0xfcc781b0ce382bf2),
                gl(0x934c69ff3ed14ba5),
                gl(0x504688a5996e8f13),
                gl(0x401f3f2ed524a2ba),
            ]
                .span()
        );

        let res = PoseidonTrait::poseidon(input);
        assert_eq!(res, expected_result);
    }

    #[test]
    fn test_hash_n_to_m() {
        let inputs = array![
            gl(0x8ccbbbea4fe5d2b7),
            gl(0xc2af59ee9ec49970),
            gl(0x90f7e1a9e658446a),
            gl(0xdcc0630a3ab8b1b8),
            gl(0x7ff8256bca20588c),
            gl(0x5d99a7ca0c44ecfb),
            gl(0x48452b17a70fbee3),
            gl(0xeb09d654690b6c88),
            gl(0x4a55d3a39c676a88),
            gl(0xc0407a38d2285139),
            gl(0xa234bac9356386d1),
            gl(0xe1633f2bad98a52f),
        ]
            .span();

        let res = hash_n_to_m_no_pad(inputs, 12);

        let expected_result = array![
            gl(6349479711091978079),
            gl(10683045036077094258),
            gl(2823735847975198144),
            gl(3985988952289670700),
            gl(5798729777066225290),
            gl(4685092000851135126),
            gl(6733136384532942948),
            gl(16907084925699390562),
            gl(17403481966703895704),
            gl(18406498950571142509),
            gl(14139074714504212678),
            gl(361636287427537691)
        ]
            .span();

        assert_eq!(res, expected_result);
    }

    #[test]
    fn test_two_to_one() {
        let left = HashOutImpl::new(
            array![
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0)
            ]
                .span()
        );

        let right = HashOutImpl::new(
            array![
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0),
                gl(0x123456789abcdef0)
            ]
                .span()
        );
        let res = hash_two_to_one(left, right);

        let expected_result = HashOutImpl::new(
            array![
                gl(9281303514704740231),
                gl(8186319561797792009),
                gl(7590563702884938881),
                gl(10671169844377727805)
            ]
                .span()
        );

        assert_eq!(res, expected_result);
    }
}
