use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::TryInto;
use core::integer::U128MulGuarantee;
use plonky2_verifier::fields::field::F;
use plonky2_verifier::fields::utils::pow;

pub extern fn u256_safe_divmod(
    lhs: u256, rhs: NonZero<u256>
) -> (u256, u256, U128MulGuarantee) implicits(RangeCheck) nopanic;


pub const P: u64 = 0xffffffff00000001; // 2^64 - 2^32 + 1 - Goldilocks Field
const P64NZ: NonZero<u64> = 0xffffffff00000001;
const P128NZ: NonZero<u128> = 0xffffffff00000001;
const P256NZ: NonZero<u256> = 0xffffffff00000001;

#[derive(Copy, Drop, Debug, PartialEq, Eq)]
pub struct Goldilocks {
    pub inner: u64
}

#[generate_trait]
pub impl GoldilocksImpl of GoldilocksTrait {
    fn reduce_u64(val: u64) -> Goldilocks {
        let (_, res) = core::integer::u64_safe_divmod(val, P64NZ);
        Goldilocks { inner: res.try_into().unwrap() }
    }


    fn reduce_u256(val: u256) -> Goldilocks {
        let (_, res, _) = u256_safe_divmod(val, P256NZ);
        Goldilocks { inner: res.try_into().unwrap() }
    }


    fn reduce_u128(val: u128) -> Goldilocks {
        let (_, res) = core::integer::u128_safe_divmod(val, P128NZ);
        Goldilocks { inner: res.try_into().unwrap() }
    }


    fn add_u64(ref self: Goldilocks, val: u64) -> Goldilocks {
        let other = GoldilocksTrait::reduce_u64(val);
        self + other
    }

    fn inv(self: Goldilocks) -> Goldilocks {
        GoldilocksField::exp_u64(@self, P - 2)
    }
}

pub impl GoldilocksAdd of core::traits::Add<Goldilocks> {
    fn add(lhs: Goldilocks, rhs: Goldilocks) -> Goldilocks {
        let res: u128 = lhs.inner.into() + rhs.inner.into();
        GoldilocksImpl::reduce_u128(res)
    }
}
pub impl GoldilocksSub of core::traits::Sub<Goldilocks> {
    fn sub(lhs: Goldilocks, rhs: Goldilocks) -> Goldilocks {
        lhs + (-rhs)
    }
}
pub impl GoldilocksMul of core::traits::Mul<Goldilocks> {
    fn mul(lhs: Goldilocks, rhs: Goldilocks) -> Goldilocks {
        GoldilocksImpl::reduce_u128(core::integer::u64_wide_mul(lhs.inner, rhs.inner))
    }
}

pub impl GoldilocksZero of core::num::traits::Zero<Goldilocks> {
    fn zero() -> Goldilocks {
        Goldilocks { inner: 0 }
    }
    fn is_zero(self: @Goldilocks) -> bool {
        *self.inner == 0
    }
    fn is_non_zero(self: @Goldilocks) -> bool {
        *self.inner != 0
    }
}


pub impl GoldilocksOne of core::num::traits::One<Goldilocks> {
    fn one() -> Goldilocks {
        Goldilocks { inner: 1 }
    }
    fn is_one(self: @Goldilocks) -> bool {
        *self.inner == 1
    }
    fn is_non_one(self: @Goldilocks) -> bool {
        *self.inner != 1
    }
}
pub impl GoldilocksNeg of Neg<Goldilocks> {
    fn neg(a: Goldilocks) -> Goldilocks {
        if a.inner == 0 {
            Goldilocks { inner: 0 }
        } else {
            Goldilocks { inner: P - a.inner }
        }
    }
}

pub impl GoldilocksField of F<Goldilocks> {
    fn TWO_ADICITY() -> usize {
        32
    }
    fn CHARACTERISTIC_TWO_ADICITY() -> usize {
        32
    }
    fn MULTIPLICATIVE_GROUP_GENERATOR() -> Goldilocks {
        Goldilocks { inner: 14293326489335486720 }
    }

    fn POWER_OF_TWO_GENERATOR() -> Goldilocks {
        Goldilocks { inner: 7277203076849721926 }
    }

    fn exp_power_of_2(self: @Goldilocks, power_log: usize) -> Goldilocks {
        let mut res = *self;
        let mut i = 0;
        while i < power_log {
            res = res * res;
            i += 1;
        };
        res
    }

    fn exp_u64(self: @Goldilocks, exp: u64) -> Goldilocks {
        let mut res = Goldilocks { inner: 1 };
        let mut exp = exp;
        let mut base = *self;
        while exp > 1 {
            if exp % 2 == 0 {
                base = base * base;
                exp = exp / 2;
            } else {
                res = res * base;
                exp = exp - 1;
            }
        };
        res * base
    }

    fn primitive_root_of_unity(n_log: usize) -> Goldilocks {
        assert!(n_log <= GoldilocksField::TWO_ADICITY());
        let base = GoldilocksField::POWER_OF_TWO_GENERATOR();
        base.exp_power_of_2(GoldilocksField::TWO_ADICITY() - n_log)
    }
}

pub impl GoldilocksDiv of core::traits::Div<Goldilocks> {
    fn div(lhs: Goldilocks, rhs: Goldilocks) -> Goldilocks {
        // Compute the multiplicative inverse of rhs
        let inv = GoldilocksField::exp_u64(@rhs, P - 2);
        // Multiply lhs by the inverse of rhs
        lhs * inv
    }
}


#[inline(always)]
pub fn gl(val: u64) -> Goldilocks {
    GoldilocksImpl::reduce_u64(val)
}

#[cfg(test)]
mod tests {
    use super::{gl, P, GoldilocksImpl};

    #[test]
    fn reduce_u256() {
        let val: u256 = 0x123456789abcdef000000000000000000000000000;
        let res = GoldilocksImpl::reduce_u256(val);

        assert_eq!(res.inner, 14675409648146780179);
    }

    #[test]
    fn test_goldilocks() {
        assert_eq!(gl(P), gl(0));
        assert_eq!(gl(P + 1), gl(1));
        assert_eq!(gl(1) + gl(2), gl(3));
        assert_eq!(gl(3) - gl(2), gl(1));
        assert_eq!(gl(P - 1) + gl(1), gl(0));
        assert_eq!(gl(0) - gl(1), gl(P - 1));
        assert_eq!(gl(0) - gl(P - 1), gl(1));
    }

    #[test]
    fn test_div() {
        let a = gl(2);
        let b = gl(3);
        let res = a / b;
        let recovered = res * b;
        assert_eq!(recovered, a);
    }
}
