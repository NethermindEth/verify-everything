use core::option::OptionTrait;
use core::traits::TryInto;
use core::result::ResultTrait;

pub const P: u64 = 0xffffffff00000001; // 2^64 - 2^32 + 1 - Goldilocks Field
const P64NZ: NonZero<u64> = 0xffffffff00000001;
const P128NZ: NonZero<u128> = 0xffffffff00000001;

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

    fn reduce_u128(val: u128) -> Goldilocks {
        let (_, res) = core::integer::u128_safe_divmod(val, P128NZ);
        Goldilocks { inner: res.try_into().unwrap() }
    }

    fn add_u64(ref self: Goldilocks, val: u64) -> Goldilocks {
        let other = GoldilocksTrait::reduce_u64(val);
        self + other
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

pub impl M31Zero of core::num::traits::Zero<Goldilocks> {
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


pub impl M31One of core::num::traits::One<Goldilocks> {
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

pub fn gl(val: u64) -> Goldilocks {
    GoldilocksImpl::reduce_u64(val)
}

#[cfg(test)]
mod tests {
    use super::{gl, P};

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
}
