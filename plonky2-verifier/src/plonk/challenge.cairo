use core::box::BoxTrait;
use core::option::OptionTrait;
use core::array::SpanTrait;
use plonky2_verifier::hash::poseidon::PoseidonPermutationTrait;
use core::array::ArrayTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks, gl};
use plonky2_verifier::fields::goldilocks_quadratic::{GoldilocksQuadratic};
use plonky2_verifier::hash::structure::{PoseidonState, HashOut};
use plonky2_verifier::hash::poseidon::{PoseidonPermutation, PoseidonPermutationImpl};
use plonky2_verifier::hash::constants::{SPONGE_RATE};
use plonky2_verifier::hash::merkle_caps::{MerkleCaps};


#[derive(Drop)]
pub struct Challenger {
    pub sponge_state: PoseidonPermutation,
    pub input_buffer: Array<Goldilocks>,
    output_buffer: Array<Goldilocks>
}
#[generate_trait]
impl ChallengerImpl of ChallengerTrait {
    fn new() -> Challenger {
        Challenger {
            sponge_state: PoseidonPermutationImpl::default(),
            input_buffer: array![],
            output_buffer: array![]
        }
    }

    fn observe_element(ref self: Challenger, element: Goldilocks) {
        self.output_buffer = array![];
        self.input_buffer.append(element);

        if self.input_buffer.len() == SPONGE_RATE {
            self.duplexing();
        }
    }

    fn observe_elements(ref self: Challenger, elements: Span<Goldilocks>) {
        let mut i = 0;
        let mut len = elements.len();
        while i < len {
            self.observe_element(*elements.get(i).unwrap().unbox());
            i += 1;
        }
    }

    fn observe_hash(ref self: Challenger, hash: HashOut) {
        self.observe_elements(hash.elements);
    }

    fn observe_cap(ref self: Challenger, merkle_caps: MerkleCaps) {
        let mut i = 0;
        let mut len = merkle_caps.data.len();
        while i < len {
            self.observe_hash(*merkle_caps.data.get(i).unwrap().unbox());
            i += 1;
        }
    }

    fn get_challenge(ref self: Challenger) -> Goldilocks {
        if !self.input_buffer.is_empty() || self.output_buffer.is_empty() {
            self.duplexing();
        }
        self.output_buffer.pop_front().unwrap()
    }

    fn get_n_challenges(ref self: Challenger, n: usize) -> Span<Goldilocks> {
        let mut challenges = array![];
        let mut i = 0;
        while i < n {
            challenges.append(self.get_challenge());
            i += 1;
        };
        challenges.span()
    }

    fn get_hash(ref self: Challenger) -> HashOut {
        HashOut { elements: self.get_n_challenges(4) }
    }

    fn get_extension_challenge(ref self: Challenger) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: self.get_challenge(), b: self.get_challenge() }
    }

    fn get_n_extention_challenges(ref self: Challenger, n: usize) -> Span<GoldilocksQuadratic> {
        let mut challenges = array![];
        let mut i = 0;
        while i < n {
            challenges.append(self.get_extension_challenge());
            i += 1;
        };
        challenges.span()
    }

    fn duplexing(ref self: Challenger) {
        self.sponge_state.set_from_slice(self.input_buffer.span(), 0);
        self.sponge_state.permute();
        self.clear_input_buffer();
        self.clear_output_buffer();
        self.append_span_to_output_buffer(self.sponge_state.squeeze());
    }

    fn append_span_to_output_buffer(ref self: Challenger, elements: Span<Goldilocks>) {
        let mut i = 0;
        let mut len = elements.len();
        while i < len {
            self.output_buffer.append(*elements.get(i).unwrap().unbox());
            i += 1;
        }
    }

    fn compact(ref self: Challenger) -> PoseidonPermutation {
        if !self.input_buffer.is_empty() {
            self.duplexing();
        }
        self.clear_output_buffer();
        self.sponge_state
    }

    fn clear_output_buffer(ref self: Challenger) {
        self.output_buffer = array![];
    }

    fn clear_input_buffer(ref self: Challenger) {
        self.input_buffer = array![];
    }
}


#[cfg(test)]
pub mod tests {
    use core::traits::Into;
    use plonky2_verifier::fields::goldilocks::{gl};
    use plonky2_verifier::plonk::challenge::ChallengerTrait;
    use super::{Challenger, ChallengerImpl};

    fn observer_range(ref challenger: Challenger, start: usize, end: usize) {
        let mut i = start;
        while i <= end {
            challenger.observe_element(gl(i.into()));
            i += 1;
        }
    }

    #[test]
    fn test_first_time_duplex() {
        let mut c = ChallengerImpl::new();
        observer_range(ref c, 1, 8);
        let expected = array![
            gl(15064728126975588673),
            gl(10314245681893968020),
            gl(11300930272442645327),
            gl(2830815762300183090),
            gl(11319090575323142028),
            gl(15863612372942915078),
            gl(11799836800976840597),
            gl(5934210966416817736)
        ];
        assert_eq!(c.output_buffer, expected);
    }

    #[test]
    fn test_empty_buffer_after_rate() {
        let mut c = ChallengerImpl::new();
        observer_range(ref c, 1, 7);
        assert_eq!(c.input_buffer.len(), 7);
        observer_range(ref c, 8, 8);
        assert_eq!(c.input_buffer.len(), 0);
    }

    #[test]
    fn test_2_duplexing_round_same_input_fail() {
        let mut c = ChallengerImpl::new();
        observer_range(ref c, 1, 8);
        observer_range(ref c, 1, 8);
        let expected = array![
            gl(15064728126975588673),
            gl(10314245681893968020),
            gl(11300930272442645327),
            gl(2830815762300183090),
            gl(11319090575323142028),
            gl(15863612372942915078),
            gl(11799836800976840597),
            gl(5934210966416817736)
        ];
        assert_ne!(c.output_buffer, expected);
    }

    #[test]
    fn test_2_duplexing_round_same_input_pass() {
        let mut c = ChallengerImpl::new();
        observer_range(ref c, 1, 8);
        observer_range(ref c, 9, 16);
        let expected = array![
            gl(16557766434377094129),
            gl(14606817572719425261),
            gl(6718403660470659989),
            gl(12761567020879903119),
            gl(5394354827830690206),
            gl(3347119598371595739),
            gl(8741199867271033280),
            gl(13530686524357655890)
        ];
        assert_eq!(c.output_buffer, expected);
    }
}
