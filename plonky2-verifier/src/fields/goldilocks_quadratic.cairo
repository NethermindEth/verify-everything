use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::TryInto;
use core::integer::U128MulGuarantee;
use plonky2_verifier::fields::field::F;
use plonky2_verifier::fields::goldilocks::{Goldilocks, GoldilocksZero, gl, GoldilocksImpl};

#[derive(Copy, Drop, Debug, PartialEq, Eq)]
pub struct GoldilocksQuadratic {
    pub a: Goldilocks,
    pub b: Goldilocks,
}

const W: Goldilocks =
    Goldilocks {
        inner: 7
    }; // Element W of BaseField, such that `X^d - W` is irreducible over BaseField.


#[generate_trait]
pub impl GoldilocksQuadraticImpl of GoldilocksQuadraticTrait {
    fn reduce_u64(val: u64) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: GoldilocksImpl::reduce_u64(val), b: Goldilocks { inner: 0 }, }
    }

    fn reduce_u256(val: u256) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: GoldilocksImpl::reduce_u256(val), b: Goldilocks { inner: 0 }, }
    }

    fn reduce_u128(val: u128) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: GoldilocksImpl::reduce_u128(val), b: Goldilocks { inner: 0 }, }
    }

    fn add_u64(ref self: GoldilocksQuadratic, val: u64) -> GoldilocksQuadratic {
        let other = GoldilocksQuadraticTrait::reduce_u64(val);
        self + other
    }
}

pub impl GoldilocksQuadraticAdd of core::traits::Add<GoldilocksQuadratic> {
    fn add(lhs: GoldilocksQuadratic, rhs: GoldilocksQuadratic) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: lhs.a + rhs.a, b: lhs.b + rhs.b }
    }
}
pub impl GoldilocksQuadraticSub of core::traits::Sub<GoldilocksQuadratic> {
    fn sub(lhs: GoldilocksQuadratic, rhs: GoldilocksQuadratic) -> GoldilocksQuadratic {
        lhs + (-rhs)
    }
}
pub impl GoldilocksQuadraticMul of core::traits::Mul<GoldilocksQuadratic> {
    fn mul(lhs: GoldilocksQuadratic, rhs: GoldilocksQuadratic) -> GoldilocksQuadratic {
        let a0 = lhs.a;
        let a1 = lhs.b;

        let b0 = rhs.a;
        let b1 = rhs.b;

        let c0 = a0 * b0 + W * a1 * b1;
        let c1 = a0 * b1 + a1 * b0;

        GoldilocksQuadratic { a: c0, b: c1 }
    }
}

pub impl GoldilocksQuadraticZero of core::num::traits::Zero<GoldilocksQuadratic> {
    fn zero() -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: Goldilocks { inner: 0 }, b: Goldilocks { inner: 0 } }
    }
    fn is_zero(self: @GoldilocksQuadratic) -> bool {
        *self.a == Goldilocks { inner: 0 } && *self.b == Goldilocks { inner: 0 }
    }
    fn is_non_zero(self: @GoldilocksQuadratic) -> bool {
        *self.a != Goldilocks { inner: 0 } || *self.b != Goldilocks { inner: 0 }
    }
}


pub impl GoldilocksQuadraticOne of core::num::traits::One<GoldilocksQuadratic> {
    fn one() -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: gl(1), b: Goldilocks { inner: 0 } }
    }
    fn is_one(self: @GoldilocksQuadratic) -> bool {
        *self.a == Goldilocks { inner: 1 } && *self.b == Goldilocks { inner: 0 }
    }
    fn is_non_one(self: @GoldilocksQuadratic) -> bool {
        *self.a != Goldilocks { inner: 1 } || *self.b != Goldilocks { inner: 0 }
    }
}


pub impl GoldilocksQuadraticNeg of Neg<GoldilocksQuadratic> {
    fn neg(a: GoldilocksQuadratic) -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: -a.a, b: -a.b }
    }
}

pub fn glq(val: u64) -> GoldilocksQuadratic {
    GoldilocksQuadraticImpl::reduce_u64(val)
}

pub impl GoldilocksQuadraticField of F<GoldilocksQuadratic> {
    fn TWO_ADICITY() -> usize {
        33
    }
    fn CHARACTERISTIC_TWO_ADICITY() -> usize {
        32
    }
    fn MULTIPLICATIVE_GROUP_GENERATOR() -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: Goldilocks { inner: 0 }, b: Goldilocks { inner: 11713931119993638672 } }
    }

    fn POWER_OF_TWO_GENERATOR() -> GoldilocksQuadratic {
        GoldilocksQuadratic { a: Goldilocks { inner: 0 }, b: Goldilocks { inner: 7226896044987257365 } }
    }

    fn exp_power_of_2(self: @GoldilocksQuadratic, power_log: usize) -> GoldilocksQuadratic {
        let mut res = *self;
        let mut i = 0;
        while i < power_log {
            res = res * res;
            i += 1;
        };
        res
    }

    fn exp_u64(self: @GoldilocksQuadratic, exp: u64) -> GoldilocksQuadratic {
        let mut res = GoldilocksQuadratic { a: gl(1), b: gl(0) };
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

    fn primitive_root_of_unity(n_log: usize) -> GoldilocksQuadratic {
        assert!(n_log <= GoldilocksQuadraticField::TWO_ADICITY());
        let base = GoldilocksQuadraticField::POWER_OF_TWO_GENERATOR();
        base.exp_power_of_2(GoldilocksQuadraticField::TWO_ADICITY() - n_log)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        gl, glq, GoldilocksQuadratic, GoldilocksQuadraticNeg, GoldilocksQuadraticOne,
        GoldilocksQuadraticZero, GoldilocksQuadraticAdd, GoldilocksQuadraticSub,
        GoldilocksQuadraticMul
    };

    #[test]
    fn test_goldilocks_quadratic_add() {
        let a = glq(3);
        let b = glq(5);
        let c = a + b;
        let expected = GoldilocksQuadratic { a: gl(8), b: gl(0) };
        assert_eq!(c, expected);
    }

    #[test]
    fn test_goldilocks_quadratic_sub() {
        let a = glq(3);
        let b = glq(5);
        let c = a - b;
        let expected = GoldilocksQuadratic { a: gl(3) - gl(5), b: gl(0) };
        assert_eq!(c, expected);
    }

    #[test]
    fn test_goldilocks_quadratic_mul() {
        let a = glq(3);
        let b = glq(5);
        let c = a * b;
        let expected = GoldilocksQuadratic { a: gl(15), b: gl(0) };
        assert_eq!(c, expected);
    }

    #[test]
    fn test_goldilocks_quadratic_zero() {
        let a = GoldilocksQuadraticZero::zero();
        assert_eq!(a, GoldilocksQuadratic { a: gl(0), b: gl(0) });
    }

    #[test]
    fn test_goldilocks_quadratic_one() {
        let a = GoldilocksQuadraticOne::one();
        assert_eq!(a, GoldilocksQuadratic { a: gl(1), b: gl(0) });
    }

    #[test]
    fn test_goldilocks_quadratic_neg() {
        let a = glq(3);
        let b = -a;
        let expected = GoldilocksQuadratic { a: gl(0) - gl(3), b: gl(0) };
        assert_eq!(b, expected);
    }

    #[test]
    fn test_goldilocks_quadratic_eq() {
        let a = glq(3);
        let b = glq(3);
        assert_eq!(a, b);
    }

    #[test]
    fn test_goldilocks_quadratic_ne() {
        let a = glq(3);
        let b = glq(5);
        assert_ne!(a, b);
    }

    #[test]
    fn test_add_ab() {
        let a = GoldilocksQuadratic { a: gl(3), b: gl(5) };
        let b = GoldilocksQuadratic { a: gl(7), b: gl(11) };
        let c = a + b;
        let expected = GoldilocksQuadratic { a: gl(10), b: gl(16) };
        assert_eq!(c, expected);
    }
}
