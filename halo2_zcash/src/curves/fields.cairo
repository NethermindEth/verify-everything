// Base field of the pallas curve

const R2: Fp = Fp{a: 10122100416058490895, b: 15551789045973377255, c: 8617542898466512152, d: 679271340751763220};
const MODULUS: Fp = Fp{a: 0x992d30ed00000001, b: 0x224698fc094cf91b, c: 0x0000000000000000, d: 0x4000000000000000};
const BITS64: u128 = 18446744073709551616;
const BITS63: u64 = 9223372036854775808; 

#[derive(Copy, Drop, Debug, PartialEq, Eq)]
pub struct Fp {
    a: u64, 
    b: u64, 
    c: u64, 
    d: u64, 
}   

#[derive(Copy, Drop, Debug, PartialEq, Eq)]
pub struct Fq {
    a: u64, 
    b: u64, 
    c: u64, 
    d: u64, 
}

#[derive(Copy, Drop, Debug, PartialEq, Eq)]
pub struct EpAffine {
    x: Fp,
    y: Fq
}

impl U64IntoFp of Into<u64, Fp> {
    fn into(self: u64) -> Fp {
        Fp {a: self, b: 0, c: 0, d: 0}
    }
}

impl U64IntoFq of Into<u64, Fq> {
    fn into(self: u64) -> Fq {
        Fq {a: self, b: 0, c: 0, d: 0}
    }
}

impl FpSub of Sub<Fp> {
    fn sub(lhs: Fp, rhs: Fp) -> Fp {
        let (d0, borrow) = sbb(lhs.a, rhs.a, 0);
        let (d1, borrow) = sbb(lhs.b, rhs.b, borrow);
        let (d2, borrow) = sbb(lhs.c, rhs.c, borrow);
        let (d3, borrow) = sbb(lhs.d, rhs.d, borrow);

        let (d0, carry) = adc(d0, MODULUS.a & borrow, 0);
        let (d1, carry) = adc(d1, MODULUS.b & borrow, carry);
        let (d2, carry) = adc(d2, MODULUS.c & borrow, carry);
        let (d3, _) = adc(d3, MODULUS.d & borrow, carry);

        Fp {a: d0, b: d1, c: d2, d: d3}
    }
}

fn sub(lhs: @Fp, rhs: @Fp) -> Fp {
    let (d0, borrow) = sbb(*lhs.a, *rhs.a, 0);
    let (d1, borrow) = sbb(*lhs.b, *rhs.b, borrow);
    let (d2, borrow) = sbb(*lhs.c, *rhs.c, borrow);
    let (d3, borrow) = sbb(*lhs.d, *rhs.d, borrow);

    let (d0, carry) = adc(d0, MODULUS.a & borrow, 0);
    let (d1, carry) = adc(d1, MODULUS.b & borrow, carry);
    let (d2, carry) = adc(d2, MODULUS.c & borrow, carry);
    let (d3, _) = adc(d3, MODULUS.d & borrow, carry);

    Fp {a: d0, b: d1, c: d2, d: d3}
}


/// Compute a + b + carry, returning the result and the new carry over.
#[inline(always)]
pub fn adc(a: u64, b: u64, carry: u64) -> (u64, u64) {
    let ret: u128 = a.into() + b.into() + carry.into();
    (ret.try_into().unwrap(), (ret / BITS64).try_into().unwrap())
}

/// Compute a - (b + borrow), returning the result and the new borrow.
#[inline(always)]
pub fn sbb(a: u64, b: u64, borrow: u64) -> (u64, u64) {
    let ret: u128 = wrapping_sub(a.into(), (b.into() + (borrow / BITS63).into()));
    (ret.try_into().unwrap(), (ret / BITS64).try_into().unwrap())
}

/// Compute a + (b * c) + carry, returning the result and the new carry over.
#[inline(always)]
pub fn mac(a: u64, b: u64, c: u64, borrow: u64) -> (u64, u64) {
    let ret: u128 = a.into() + (b.into() * c.into()) + c.into();
    (ret.try_into().unwrap(), (ret / BITS64).try_into().unwrap())
}

// Modulus Wrapping Functions
pub fn wrapping_sub(a: u128, b: u128) -> u128 {
    if a >= b {
        a - b
    } else {
        0xFFFFFFFFFFFFFFFF_u128 - (b - a) + 1
    }
}