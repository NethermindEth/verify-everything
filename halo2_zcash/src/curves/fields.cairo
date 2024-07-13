// Base field of the pallas curve
use super::utils;
use super::utils::{BITS128_MASK_64, BITS64_2_POW_63, BITS128_2_POW_64};

pub trait Field<T> {
    fn one() -> T;
    fn zero() -> T;
}


// TODO (Daniel): Implement Debug trait 
pub mod Fp {
    use super::{adc, mac, sbb};
    use super::utils; 
    use super::utils::{BITS128_MASK_64, BITS64_2_POW_63, BITS128_2_POW_64};

    #[derive(Copy, Drop, Debug, PartialEq, Eq)]
    pub struct Fp {
        a: u64, 
        b: u64, 
        c: u64, 
        d: u64, 
    }   

    /// INV = -(p^{-1} mod 2^64) mod 2^64
    const INV: u64 = 0x992d30ecffffffff;

    /// R = 2^256 mod p
    const R: Fp = Fp{
        a: 0x34786d38fffffffd,
        b: 0x992c350be41914ad,
        c: 0xffffffffffffffff,
        d: 0x3fffffffffffffff,
    };

    /// R^2 = 2^512 mod p
    const R2: Fp = Fp{
        a: 0x8c78ecb30000000f,
        b: 0xd7d30dbd8b0de0e7,
        c: 0x7797a99bc3c95d18,
        d: 0x096d41af7b9cb714,
    };

    /// R^3 = 2^768 mod p
    const R3: Fp = Fp{
        a: 0xf185a5993a9e10f9,
        b: 0xf6a68f3b6ac5b1d1,
        c: 0xdf8d1014353fd42c,
        d: 0x2ae309222d2d9910,
    };

    /// Constant representing the modulus
    /// p = 0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001
    const MODULUS: Fp = Fp{
        a: 0x992d30ed00000001, 
        b: 0x224698fc094cf91b, 
        c: 0x0000000000000000, 
        d: 0x4000000000000000
    };

    pub impl FieldFp of super::Field<Fp> {
        fn one() -> Fp {
            R
        }

        fn zero() -> Fp {
            Fp {a: 0, b: 0, c: 0, d: 0}
        }
    }

    impl U64IntoFp of Into<u64, Fp> {
        fn into(self: u64) -> Fp {
            Fp {a: self, b: 0, c: 0, d: 0} * R2
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

    impl FpAdd of Add<Fp> {
        fn add(lhs: Fp, rhs: Fp) -> Fp { 
            let (d0, carry) = adc(lhs.a, rhs.a, 0);
            let (d1, carry) = adc(lhs.b, rhs.b, carry);
            let (d2, carry) = adc(lhs.c, rhs.c, carry);
            let (d3, _) = adc(lhs.d, rhs.d, carry);
            sub(@Fp{a: d0, b: d1, c: d2, d: d3}, @MODULUS)
        }
    }

    fn add(lhs: @Fp, rhs: @Fp) -> Fp { 
        let (d0, carry) = adc(*lhs.a, *rhs.a, 0);
        let (d1, carry) = adc(*lhs.b, *rhs.b, carry);
        let (d2, carry) = adc(*lhs.c, *rhs.c, carry);
        let (d3, _) = adc(*lhs.d, *rhs.d, carry);
        
        sub(@Fp{a: d0, b: d1, c: d2, d: d3}, @MODULUS)
    }

    impl FpNeg of Neg<Fp> {
        fn neg(a: Fp) -> Fp {
            let (d0, borrow) = sbb(MODULUS.a, a.a, 0);
            let (d1, borrow) = sbb(MODULUS.b, a.b, borrow);
            let (d2, borrow) = sbb(MODULUS.c, a.c, borrow);
            let (d3, _) = sbb(MODULUS.d, a.d, borrow);
            
            let mask = utils::wrapping_sub_u64(utils::bti((a.a | a.b | a.c | a.d) == 0) , 1); 

            Fp {a: d0 & mask, b: d1 & mask, c: d2 & mask, d: d3 & mask}
        }
    }

    fn montgomery_reduce(r0: u64,
        r1: u64,
        r2: u64,
        r3: u64,
        r4: u64,
        r5: u64,
        r6: u64,
        r7: u64) -> Fp {
            
            let k = utils::wrapping_mul_u64(r0, INV);
            let (_, carry) = mac(r0, k, MODULUS.a, 0);
            let (r1, carry) = mac(r1, k, MODULUS.b, carry);
            let (r2, carry) = mac(r2, k, MODULUS.c, carry);
            let (r3, carry) = mac(r3, k, MODULUS.d, carry);
            let (r4, carry2) = adc(r4, 0, carry);

            let k = utils::wrapping_mul_u64(r1, INV);
            let (_, carry) = mac(r1, k, MODULUS.a, 0);
            let (r2, carry) = mac(r2, k, MODULUS.b, carry);
            let (r3, carry) = mac(r3, k, MODULUS.c, carry);
            let (r4, carry) = mac(r4, k, MODULUS.d, carry);
            let (r5, carry2) = adc(r5, carry2, carry);

            let k = utils::wrapping_mul_u64(r2, INV);
            let (_, carry) = mac(r2, k, MODULUS.a, 0);
            let (r3, carry) = mac(r3, k, MODULUS.b, carry);
            let (r4, carry) = mac(r4, k, MODULUS.c, carry);
            let (r5, carry) = mac(r5, k, MODULUS.d, carry);
            let (r6, carry2) = adc(r6, carry2, carry);

            let k = utils::wrapping_mul_u64(r3, INV);
            let (_, carry) = mac(r3, k, MODULUS.a, 0);
            let (r4, carry) = mac(r4, k, MODULUS.b, carry);
            let (r5, carry) = mac(r5, k, MODULUS.c, carry);
            let (r6, carry) = mac(r6, k, MODULUS.d, carry);
            let (r7, _) = adc(r7, carry2, carry);

            sub(@Fp{a: r4, b: r5, c: r6, d: r7}, @MODULUS)
        }

    impl FpMul of Mul<Fp> {
        fn mul(lhs: Fp, rhs: Fp) -> Fp {
            let (r0, carry) = mac(0, lhs.a, rhs.a, 0);
            let (r1, carry) = mac(0, lhs.a, rhs.b, carry);
            let (r2, carry) = mac(0, lhs.a, rhs.c, carry);
            let (r3, r4) = mac(0, lhs.a, rhs.d, carry);

            let (r1, carry) = mac(r1, lhs.b, rhs.a, 0);
            let (r2, carry) = mac(r2, lhs.b, rhs.b, carry);
            let (r3, carry) = mac(r3, lhs.b, rhs.c, carry);
            let (r4, r5) = mac(r4, lhs.b, rhs.d, carry);

            let (r2, carry) = mac(r2, lhs.c, rhs.a, 0);
            let (r3, carry) = mac(r3, lhs.c, rhs.b, carry);
            let (r4, carry) = mac(r4, lhs.c, rhs.c, carry);
            let (r5, r6) = mac(r5, lhs.c, rhs.d, carry);

            let (r3, carry) = mac(r3, lhs.d, rhs.a, 0);
            let (r4, carry) = mac(r4, lhs.d, rhs.b, carry);
            let (r5, carry) = mac(r5, lhs.d, rhs.c, carry);
            let (r6, r7) = mac(r6, lhs.d, rhs.d, carry);
            
            montgomery_reduce(r0, r1, r2, r3, r4, r5, r6, r7)
        }
    }

}

pub mod Fq {
    use super::{adc, mac, sbb};
    use super::utils; 
    use super::utils::{BITS128_MASK_64, BITS64_2_POW_63, BITS128_2_POW_64};

    #[derive(Copy, Drop, Debug, PartialEq, Eq)]
    pub struct Fq {
        a: u64, 
        b: u64, 
        c: u64, 
        d: u64, 
    }

    /// INV = -(q^{-1} mod 2^64) mod 2^64
    const INV: u64 = 0x8c46eb20ffffffff;

    /// R = 2^256 mod q
    const R: Fq = Fq{
        a: 0x5b2b3e9cfffffffd,
        b: 0x992c350be3420567,
        c: 0xffffffffffffffff,
        d: 0x3fffffffffffffff,
    };

    /// R^2 = 2^512 mod q
    const R2: Fq = Fq{
        a: 0xfc9678ff0000000f,
        b: 0x67bb433d891a16e3,
        c: 0x7fae231004ccf590,
        d: 0x096d41af7ccfdaa9,
    };

    /// R^3 = 2^768 mod q
    const R3: Fq = Fq{
        a: 0x008b421c249dae4c,
        b: 0xe13bda50dba41326,
        c: 0x88fececb8e15cb63,
        d: 0x07dd97a06e6792c8,
    };

    /// Constant representing the modulus
    /// q = 0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001
    const MODULUS: Fq = Fq{
        a: 0x8c46eb2100000001,
        b: 0x224698fc0994a8dd,
        c: 0x0,
        d: 0x4000000000000000,
    };

    pub impl FieldFq of super::Field<Fq> {
        fn one() -> Fq {
            R
        }

        fn zero() -> Fq {
            Fq {a: 0, b: 0, c: 0, d: 0}
        }
    }

    impl U64IntoFq of Into<u64, Fq> {
        fn into(self: u64) -> Fq {
            Fq {a: self, b: 0, c: 0, d: 0} * R2
        }
    }

    impl FqSub of Sub<Fq> {
        fn sub(lhs: Fq, rhs: Fq) -> Fq {
            let (d0, borrow) = sbb(lhs.a, rhs.a, 0);
            let (d1, borrow) = sbb(lhs.b, rhs.b, borrow);
            let (d2, borrow) = sbb(lhs.c, rhs.c, borrow);
            let (d3, borrow) = sbb(lhs.d, rhs.d, borrow);

            let (d0, carry) = adc(d0, MODULUS.a & borrow, 0);
            let (d1, carry) = adc(d1, MODULUS.b & borrow, carry);
            let (d2, carry) = adc(d2, MODULUS.c & borrow, carry);
            let (d3, _) = adc(d3, MODULUS.d & borrow, carry);

            Fq {a: d0, b: d1, c: d2, d: d3}
        }
    }

    fn sub(lhs: @Fq, rhs: @Fq) -> Fq {
        let (d0, borrow) = sbb(*lhs.a, *rhs.a, 0);
        let (d1, borrow) = sbb(*lhs.b, *rhs.b, borrow);
        let (d2, borrow) = sbb(*lhs.c, *rhs.c, borrow);
        let (d3, borrow) = sbb(*lhs.d, *rhs.d, borrow);

        let (d0, carry) = adc(d0, MODULUS.a & borrow, 0);
        let (d1, carry) = adc(d1, MODULUS.b & borrow, carry);
        let (d2, carry) = adc(d2, MODULUS.c & borrow, carry);
        let (d3, _) = adc(d3, MODULUS.d & borrow, carry);

        Fq {a: d0, b: d1, c: d2, d: d3}
    }

    impl FqAdd of Add<Fq> {
        fn add(lhs: Fq, rhs: Fq) -> Fq { 
            let (d0, carry) = adc(lhs.a, rhs.a, 0);
            let (d1, carry) = adc(lhs.b, rhs.b, carry);
            let (d2, carry) = adc(lhs.c, rhs.c, carry);
            let (d3, _) = adc(lhs.d, rhs.d, carry);
            sub(@Fq{a: d0, b: d1, c: d2, d: d3}, @MODULUS)
        }
    }

    fn add(lhs: @Fq, rhs: @Fq) -> Fq { 
        let (d0, carry) = adc(*lhs.a, *rhs.a, 0);
        let (d1, carry) = adc(*lhs.b, *rhs.b, carry);
        let (d2, carry) = adc(*lhs.c, *rhs.c, carry);
        let (d3, _) = adc(*lhs.d, *rhs.d, carry);
        
        sub(@Fq{a: d0, b: d1, c: d2, d: d3}, @MODULUS)
    }

    impl FqNeg of Neg<Fq> {
        fn neg(a: Fq) -> Fq {
            let (d0, borrow) = sbb(MODULUS.a, a.a, 0);
            let (d1, borrow) = sbb(MODULUS.b, a.b, borrow);
            let (d2, borrow) = sbb(MODULUS.c, a.c, borrow);
            let (d3, _) = sbb(MODULUS.d, a.d, borrow);
            
            let mask = utils::wrapping_sub_u64(utils::bti((a.a | a.b | a.c | a.d) == 0) , 1); 

            Fq {a: d0 & mask, b: d1 & mask, c: d2 & mask, d: d3 & mask}
        }
    }

    fn montgomery_reduce(r0: u64,
        r1: u64,
        r2: u64,
        r3: u64,
        r4: u64,
        r5: u64,
        r6: u64,
        r7: u64) -> Fq {
            
            let k = utils::wrapping_mul_u64(r0, INV);
            let (_, carry) = mac(r0, k, MODULUS.a, 0);
            let (r1, carry) = mac(r1, k, MODULUS.b, carry);
            let (r2, carry) = mac(r2, k, MODULUS.c, carry);
            let (r3, carry) = mac(r3, k, MODULUS.d, carry);
            let (r4, carry2) = adc(r4, 0, carry);

            let k = utils::wrapping_mul_u64(r1, INV);
            let (_, carry) = mac(r1, k, MODULUS.a, 0);
            let (r2, carry) = mac(r2, k, MODULUS.b, carry);
            let (r3, carry) = mac(r3, k, MODULUS.c, carry);
            let (r4, carry) = mac(r4, k, MODULUS.d, carry);
            let (r5, carry2) = adc(r5, carry2, carry);

            let k = utils::wrapping_mul_u64(r2, INV);
            let (_, carry) = mac(r2, k, MODULUS.a, 0);
            let (r3, carry) = mac(r3, k, MODULUS.b, carry);
            let (r4, carry) = mac(r4, k, MODULUS.c, carry);
            let (r5, carry) = mac(r5, k, MODULUS.d, carry);
            let (r6, carry2) = adc(r6, carry2, carry);

            let k = utils::wrapping_mul_u64(r3, INV);
            let (_, carry) = mac(r3, k, MODULUS.a, 0);
            let (r4, carry) = mac(r4, k, MODULUS.b, carry);
            let (r5, carry) = mac(r5, k, MODULUS.c, carry);
            let (r6, carry) = mac(r6, k, MODULUS.d, carry);
            let (r7, _) = adc(r7, carry2, carry);

            sub(@Fq{a: r4, b: r5, c: r6, d: r7}, @MODULUS)
        }

    impl FqMul of Mul<Fq> {
        fn mul(lhs: Fq, rhs: Fq) -> Fq {
            let (r0, carry) = mac(0, lhs.a, rhs.a, 0);
            let (r1, carry) = mac(0, lhs.a, rhs.b, carry);
            let (r2, carry) = mac(0, lhs.a, rhs.c, carry);
            let (r3, r4) = mac(0, lhs.a, rhs.d, carry);

            let (r1, carry) = mac(r1, lhs.b, rhs.a, 0);
            let (r2, carry) = mac(r2, lhs.b, rhs.b, carry);
            let (r3, carry) = mac(r3, lhs.b, rhs.c, carry);
            let (r4, r5) = mac(r4, lhs.b, rhs.d, carry);

            let (r2, carry) = mac(r2, lhs.c, rhs.a, 0);
            let (r3, carry) = mac(r3, lhs.c, rhs.b, carry);
            let (r4, carry) = mac(r4, lhs.c, rhs.c, carry);
            let (r5, r6) = mac(r5, lhs.c, rhs.d, carry);

            let (r3, carry) = mac(r3, lhs.d, rhs.a, 0);
            let (r4, carry) = mac(r4, lhs.d, rhs.b, carry);
            let (r5, carry) = mac(r5, lhs.d, rhs.c, carry);
            let (r6, r7) = mac(r6, lhs.d, rhs.d, carry);
            
            montgomery_reduce(r0, r1, r2, r3, r4, r5, r6, r7)
        }
    }


}


// #[derive(Copy, Drop, Debug, PartialEq, Eq)]
// pub struct EpAffine {
//     x: Fp,
//     y: Fq
// }

/// Compute a + b + carry, returning the result and the new carry over.
#[inline(always)]
pub fn adc(a: u64, b: u64, carry: u64) -> (u64, u64) {
    let ret: u128 = a.into() + b.into() + carry.into();
    ((ret & BITS128_MASK_64).try_into().unwrap(), (ret / BITS128_2_POW_64).try_into().unwrap())
}

/// Compute a - (b + borrow), returning the result and the new borrow.
#[inline(always)]
pub fn sbb(a: u64, b: u64, borrow: u64) -> (u64, u64) {
    let ret: u128 = utils::wrapping_sub_u128(a.into(), (b.into() + (borrow / BITS64_2_POW_63).into()));
    ((ret & BITS128_MASK_64).try_into().unwrap(), (ret / BITS128_2_POW_64 ).try_into().unwrap()) // Since no bitshift, using mask instead
}

/// Compute a + (b * c) + carry, returning the result and the new carry over.
#[inline(always)]
pub fn mac(a: u64, b: u64, c: u64, carry: u64) -> (u64, u64) {
    let ret: u128 = a.into() + (b.into() * c.into()) + carry.into();
    ((ret & BITS128_MASK_64).try_into().unwrap(), (ret / BITS128_2_POW_64).try_into().unwrap())
}

#[cfg(test)]
mod test {
    use super::Fp::{Fp, FieldFp}; 
    use super::Fq::{Fq, FieldFq}; 

    #[test]
    fn test_fp_operations () {
        // Into Trait
        let x: Fp = FieldFp::one();
        let y: Fp = 1_u64.into();
        assert!(x == y);
        
        // Addition
        let y: Fp = 2_u64.into();
        assert!(x + x == y);

        // Subtraction
        assert!(y - x == x);

        // Multiplication
        assert!(y * y == y + y);

        // Inverse
        assert!(x - y == -x);
    }

    #[test]
    fn test_fq_operations () {
        // Into Trait
        let x: Fq = FieldFq::one();
        let y: Fq = 1_u64.into();
        assert!(x == y);
        
        // Addition
        let y: Fq = 2_u64.into();
        assert!(x + x == y);

        // Subtraction
        assert!(y - x == x);

        // Multiplication
        assert!(y * y == y + y);

        // Inverse
        assert!(x - y == -x);
    }

}