use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::TryInto;
use core::integer::U128MulGuarantee;

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
        assert_eq!(c.a, gl(8));
        assert_eq!(c.b, gl(0));
    }

    #[test]
    fn test_goldilocks_quadratic_sub() {
        let a = glq(3);
        let b = glq(5);
        let c = a - b;
        assert_eq!(c.a, gl(3) - gl(5));
        assert_eq!(c.b, gl(0));
    }

    #[test]
    fn test_goldilocks_quadratic_mul() {
        let a = glq(3);
        let b = glq(5);
        let c = a * b;
        assert_eq!(c.a, gl(15));
        assert_eq!(c.b, gl(0));
    }

    #[test]
    fn test_goldilocks_quadratic_zero() {
        let a = GoldilocksQuadraticZero::zero();
        assert_eq!(a.a, gl(0));
        assert_eq!(a.b, gl(0));
    }

    #[test]
    fn test_goldilocks_quadratic_one() {
        let a = GoldilocksQuadraticOne::one();
        assert_eq!(a.a, gl(1));
        assert_eq!(a.b, gl(0));
    }

    #[test]
    fn test_goldilocks_quadratic_neg() {
        let a = glq(3);
        let b = -a;
        assert_eq!(b.a, -gl(3));
        assert_eq!(b.b, gl(0));
    }
}
