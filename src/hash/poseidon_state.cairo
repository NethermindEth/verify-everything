use plonky2_verifier::fields::goldilocks::{Goldilocks, goldilocks};

#[derive(Clone, Drop, Debug)]
pub struct PoseidonState {
    pub s0: Goldilocks,
    pub s1: Goldilocks,
    pub s2: Goldilocks,
    pub s3: Goldilocks,
    pub s4: Goldilocks,
    pub s5: Goldilocks,
    pub s6: Goldilocks,
    pub s7: Goldilocks,
    pub s8: Goldilocks,
    pub s9: Goldilocks,
    pub s10: Goldilocks,
    pub s11: Goldilocks,
}

#[generate_trait]
pub impl PoseidonStateArray of PoseidonStateArrarTrait  {
    fn default() -> PoseidonState {
        PoseidonState {
            s0: goldilocks(0),
            s1: goldilocks(0),
            s2: goldilocks(0),
            s3: goldilocks(0),
            s4: goldilocks(0),
            s5: goldilocks(0),
            s6: goldilocks(0),
            s7: goldilocks(0),
            s8: goldilocks(0),
            s9: goldilocks(0),
            s10: goldilocks(0),
            s11: goldilocks(0),
        }
    }

    fn new(elts: Span<Goldilocks>) -> PoseidonState {
        PoseidonState {
            s0: *elts.get(0).unwrap().unbox(),
            s1: *elts.get(1).unwrap().unbox(),
            s2: *elts.get(2).unwrap().unbox(),
            s3: *elts.get(3).unwrap().unbox(),
            s4: *elts.get(4).unwrap().unbox(),
            s5: *elts.get(5).unwrap().unbox(),
            s6: *elts.get(6).unwrap().unbox(),
            s7: *elts.get(7).unwrap().unbox(),
            s8: *elts.get(8).unwrap().unbox(),
            s9: *elts.get(9).unwrap().unbox(),
            s10: *elts.get(10).unwrap().unbox(),
            s11: *elts.get(11).unwrap().unbox(),
        }
    }

    fn at(self: @PoseidonState, idx: usize) -> Goldilocks {
        match idx {
            0 => *self.s0,
            1 => *self.s1,
            2 => *self.s2,
            3 => *self.s3,
            4 => *self.s4,
            5 => *self.s5,
            6 => *self.s6,
            7 => *self.s7,
            8 => *self.s8,
            9 => *self.s9,
            10 => *self.s10,
            11 => *self.s11,
            _ => goldilocks(0),
        }
    }

    fn set(ref self: PoseidonState,  elt: Goldilocks, idx: usize) {
        match idx {
            0 => self.s0 = elt,
            1 => self.s1 = elt,
            2 => self.s2 = elt,
            3 => self.s3 = elt,
            4 => self.s4 = elt,
            5 => self.s5 = elt,
            6 => self.s6 = elt,
            7 => self.s7 = elt,
            8 => self.s8 = elt,
            9 => self.s9 = elt,
            10 => self.s10 = elt,
            11 => self.s11 = elt,
            _ => (),
        }
    }
}
