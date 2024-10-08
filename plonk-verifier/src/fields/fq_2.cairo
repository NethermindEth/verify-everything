use core::traits::TryInto;
use plonk_verifier::traits::{FieldUtils, FieldOps, FieldShortcuts, FieldMulShortcuts};
use plonk_verifier::fast_mod::{u512_high_add};
use plonk_verifier::curve::{u512, U512BnAdd, U512BnSub, u512_reduce, u512_add, u512_sub};
use plonk_verifier::fields::fq_generics::{TFqAdd, TFqSub, TFqMul, TFqDiv, TFqNeg, TFqPartialEq,};
use plonk_verifier::curve::{FIELD, get_field_nz, scale_9};
use plonk_verifier::fields::{Fq, fq,};
use debug::PrintTrait;
use plonk_verifier::fields::print::u512Display;

#[derive(Copy, Drop, Serde, Debug)]
struct Fq2 {
    c0: Fq,
    c1: Fq,
}

#[inline(always)]
fn fq2(c0: u256, c1: u256) -> Fq2 {
    Fq2 { c0: fq(c0), c1: fq(c1), }
}

impl Fq2IntoU512Tuple of Into<Fq2, (u512, u512)> {
    #[inline(always)]
    fn into(self: Fq2) -> (u512, u512) {
        (
            u512 { limb0: self.c0.c0.low, limb1: self.c0.c0.high, limb2: 0, limb3: 0, },
            u512 { limb0: self.c1.c0.low, limb1: self.c1.c0.high, limb2: 0, limb3: 0, }
        )
    }
}

#[generate_trait]
impl Fq2Frobenius of Fq2FrobeniusTrait {
    #[inline(always)]
    fn frob0(self: Fq2) -> Fq2 {
        self
    }

    #[inline(always)]
    fn frob1(self: Fq2) -> Fq2 {
        self.conjugate()
    }
}

impl Fq2Utils of FieldUtils<Fq2, Fq> {
    #[inline(always)]
    fn one() -> Fq2 {
        fq2(1, 0)
    }

    #[inline(always)]
    fn zero() -> Fq2 {
        fq2(0, 0)
    }

    #[inline(always)]
    fn scale(self: Fq2, by: Fq) -> Fq2 {
        Fq2 { c0: self.c0 * by, c1: self.c1 * by, }
    }

    #[inline(always)]
    fn conjugate(self: Fq2) -> Fq2 {
        Fq2 { c0: self.c0, c1: -self.c1, }
    }

    #[inline(always)]
    fn mul_by_nonresidue(self: Fq2,) -> Fq2 {
        let Fq2 { c0: a0, c1: a1 } = self;
        // fq2(9, 1)
        Fq2 { //
         //  a0 * b0 + a1 * βb1,
        c0: scale_9(a0) - a1, //
         //  c1: a0 * b1 + a1 * b0,
        c1: a0 + scale_9(a1), //
         }
    }

    #[inline(always)]
    fn frobenius_map(self: Fq2, power: usize) -> Fq2 {
        if power % 2 == 0 {
            self
        } else {
            // Fq2 { c0: self.c0, c1: self.c1.mul_by_nonresidue(), }
            self.conjugate()
        }
    }
}

impl Fq2Short of FieldShortcuts<Fq2> {
    #[inline(always)]
    fn u_add(self: Fq2, rhs: Fq2) -> Fq2 {
        // Operation without modding can only be done like 4 times
        Fq2 { //
         c0: self.c0.u_add(rhs.c0), //
         c1: self.c1.u_add(rhs.c1), //
         }
    }

    #[inline(always)]
    fn u_sub(self: Fq2, rhs: Fq2) -> Fq2 {
        // Operation without modding can only be done like 4 times
        Fq2 { //
         c0: self.c0.u_sub(rhs.c0), //
         c1: self.c1.u_sub(rhs.c1), //
         }
    }

    #[inline(always)]
    fn fix_mod(self: Fq2) -> Fq2 {
        // Operation without modding can only be done like 4 times
        Fq2 { //
         c0: self.c0.fix_mod(), //
         c1: self.c1.fix_mod(), //
         }
    }
}

impl Fq2MulShort of FieldMulShortcuts<Fq2, (u512, u512)> {
    #[inline(always)]
    fn u512_add_fq(self: (u512, u512), rhs: Fq2) -> (u512, u512) {
        let (C0, C1) = self;
        (C0.u512_add_fq(rhs.c0), C1.u512_add_fq(rhs.c1))
    }

    #[inline(always)]
    fn u512_sub_fq(self: (u512, u512), rhs: Fq2) -> (u512, u512) {
        let (C0, C1) = self;
        (C0.u512_sub_fq(rhs.c0), C1.u512_sub_fq(rhs.c1))
    }

    fn u_mul(self: Fq2, rhs: Fq2) -> (u512, u512) {
        // Input: a = (a0 + a1i) and b = (b0 + b1i) ∈ Fp2 Output: c = a·b = (c0 +c1i) ∈ Fp2
        let Fq2 { c0: a0, c1: a1 } = self;
        let Fq2 { c0: b0, c1: b1 } = rhs;

        // 1: T0 ←a0 × b0, T1 ←a1 × b1,
        let T0 = a0.u_mul(b0); // Karatsuba V0
        let T1 = a1.u_mul(b1); // Karatsuba V1
        // t0 ←a0 +a1, t1 ←b0 +b1 2: T2 ←t0 × t1
        let T2 = a0.u_add(a1).u_mul(b0.u_add(b1));
        // T3 ←T0 + T1
        let T3 = u512_add(T0, T1);
        // 3: T3 ←T2 − T3
        let T3 = u512_sub(T2, T3);
        // 4: T4 ← T0 ⊖ T1
        let T4 = T0 - T1;
        // 5: return c = (T4 + T3i)
        (T4, T3)
    }

    fn u_sqr(self: Fq2) -> (u512, u512) {
        let Fq2 { c0: a0, c1: a1 } = self;

        // 1: t0 ← a0 + a1, t1 ← a0 ⊖ a1
        let t0 = a0.u_add(a1);
        let t1 = a0 - a1; // ⊖ = modded sub
        // 2: T0 ← t0 × t1
        let T0 = t0.u_mul(t1);
        // 3: t0 ← a0 + a0
        let t0 = a0.u_add(a0);
        // 4: T1 ← t0 × a1
        let T1 = t0.u_mul(a1);
        // 5: return C = (T0 + T1i)
        (T0, T1)
    }

    #[inline(always)]
    fn to_fq(self: (u512, u512), field_nz: NonZero<u256>) -> Fq2 {
        let (C0, C1) = self;
        fq2(u512_reduce(C0, field_nz), u512_reduce(C1, field_nz))
    }
}

impl Fq2Ops of FieldOps<Fq2> {
    #[inline(always)]
    fn add(self: Fq2, rhs: Fq2) -> Fq2 {
        Fq2 { c0: self.c0 + rhs.c0, c1: self.c1 + rhs.c1, }
    }

    #[inline(always)]
    fn sub(self: Fq2, rhs: Fq2) -> Fq2 {
        Fq2 { c0: self.c0 - rhs.c0, c1: self.c1 - rhs.c1, }
    }

    #[inline(always)]
    fn mul(self: Fq2, rhs: Fq2) -> Fq2 {
        let field_nz = get_field_nz();
        self.u_mul(rhs).to_fq(field_nz)
    }

    #[inline(always)]
    fn div(self: Fq2, rhs: Fq2) -> Fq2 {
        self.mul(rhs.inv(get_field_nz()))
    }

    #[inline(always)]
    fn neg(self: Fq2) -> Fq2 {
        Fq2 { c0: -self.c0, c1: -self.c1, }
    }

    #[inline(always)]
    fn eq(lhs: @Fq2, rhs: @Fq2) -> bool {
        lhs.c0 == rhs.c0 && lhs.c1 == rhs.c1
    }

    #[inline(always)]
    fn sqr(self: Fq2) -> Fq2 {
        // Aranha sqr_u + 2r
        let field_nz = get_field_nz();
        self.u_sqr().to_fq(field_nz)
    }

    #[inline(always)]
    fn inv(self: Fq2, field_nz: NonZero<u256>) -> Fq2 {
        let Fq2 { c0, c1 } = self;
        let t = u512_add(c0.u_sqr(), c1.u_sqr()).to_fq(field_nz).inv(field_nz);
        Fq2 { c0: c0 * t, c1: c1 * -t, }
    }
}

// Inverse unreduced Fq2
#[inline(always)]
fn ufq2_inv(self: Fq2, field_nz: NonZero<u256>) -> Fq2 {
    let Fq2 { c0, c1 } = self;
    let t = (c0.u_sqr() + c1.u_sqr()).to_fq(field_nz).inv(field_nz);
    Fq2 { c0: c0 * t, c1: c1 * -t, }
}
