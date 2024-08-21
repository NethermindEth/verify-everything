use core::option::OptionTrait;
use core::traits::TryInto;
use plonk_verifier::fast_mod as f;
use f::{u512, u512Display};
use plonk_verifier::curve::{FIELD, get_field_nz};
use debug::PrintTrait;

const a: u256 = 9099547013904003590785796930435194473319680151794113978918064868415326638035;
const b: u256 = 8021715850804026033197027745655159931503181100513576347155970296011118125764;

#[inline(always)]
fn mu512(limb0: u128, limb1: u128, limb2: u128, limb3: u128) -> u512 {
    u512 { limb0, limb1, limb2, limb3 }
}

mod bench {
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use super::mu512;
    use plonk_verifier::fast_mod as f;
    use f::{u512};
    use super::{a, b, FIELD, get_field_nz};
    #[test]
    fn add() {
        f::add(a, b, FIELD);
    }

    #[test]
    fn sub() {
        f::sub(a, b, FIELD);
    }

    #[test]
    fn mul() {
        f::mul(a, b, FIELD);
    }

    #[test]
    fn scl() {
        f::scl(a, b.low, get_field_nz());
    }

    #[test]
    fn sqr() {
        f::sqr_nz(a, get_field_nz());
    }

    #[test]
    fn div() {
        f::div(a, b, FIELD);
    }

    #[test]
    fn inv() {
        f::inv(a, get_field_nz());
    }

    #[test]
    fn rdc() {
        f::reduce(a, b.try_into().unwrap());
    }

    #[test]
    fn add_u() {
        f::add_u(a, b);
    }

    #[test]
    fn sub_u() {
        f::sub_u(a, b);
    }

    #[test]
    fn mul_u() {
        f::mul_u(a, b);
    }

    #[test]
    fn scl_u() {
        f::scl_u(a, b.low);
    }

    #[test]
    fn sqr_u() {
        f::sqr_u(a);
    }

    #[test]
    fn div_u() {
        f::div_u(a, b, get_field_nz());
    }

    #[test]
    fn u512_add() {
        f::u512_add(mu512(a.low, a.high, b.low, b.high), mu512(b.low, b.high, a.low, a.high));
    }

    #[test]
    fn u512_add_high() {
        f::u512_high_add(mu512(a.low, a.high, b.low, b.high), 5).unwrap();
    }

    #[test]
    fn u512_add_u256() {
        f::u512_add_u256(mu512(a.low, a.high, b.low, b.high), 5);
    }

    #[test]
    fn u512_sub() {
        f::u512_sub(mu512(b.low, b.high, a.low, a.high), mu512(a.low, a.high, b.low, b.high));
    }

    #[test]
    fn u512_sub_high() {
        f::u512_high_sub(mu512(a.low, a.high, b.low, b.high), 5).unwrap();
    }

    #[test]
    fn u512_sub_u256() {
        f::u512_sub_u256(mu512(a.low, a.high, b.low, b.high), 5);
    }

    #[test]
    fn u512_rdc() {
        f::u512_reduce(mu512(a.low, a.high, b.low, b.high), b.try_into().unwrap());
    }

    #[test]
    fn u512_scl() {
        f::u512_scl(mu512(a.low, a.high, b.low, b.high), b.low);
    }
}

mod bench_plain {
    use core::traits::TryInto;
    use super::{a, b, FIELD};
    #[test]
    fn add() {
        a + b;
    }

    #[test]
    fn sub() {
        a - b;
    }

    #[test]
    fn mul() {
        7_u256 * 909954701390400359078579693043519447331968015179411397891806486841532663803;
    }

    #[test]
    fn div() {
        a / b;
    }

    #[test]
    fn rem() {
        a % b;
    }
}

#[test]
fn test_all_mod_ops() {
    let max_u128: u128 = 0xffffffffffffffffffffffffffffffff;
    let add = f::add(a, b, FIELD);
    assert(
        add == 17121262864708029623982824676090354404822861252307690326074035164426444763799,
        'incorrect add'
    );
    let sub = f::sub(a, b, FIELD);
    assert(
        sub == 1077831163099977557588769184780034541816499051280537631762094572404208512271,
        'incorrect sub'
    );
    let mul = f::mul(a, b, FIELD);
    assert(
        mul == 6561477752769399547014183440960600095569924911855714080305417693732453755033,
        'incorrect mul'
    );
    let div = f::div(a, b, FIELD);
    assert(
        div == 12819640619688655488085323601008678463608009668414428319642291645922931558321,
        'incorrect div'
    );
    let sqr_mul = f::mul(a, a, FIELD);
    let sqr = f::sqr_nz(a, get_field_nz());
    assert(sqr == sqr_mul, 'incorrect square');

    let scl_mul = f::mul(a, u256 { high: 0, low: b.low }, FIELD);
    let scl = f::scl(a, b.low, get_field_nz());
    assert(scl == scl_mul, 'incorrect square');

    assert(
        f::u512_add(mu512(max_u128, 1, 2, 3), mu512(4, 5, 6, 7)) == mu512(3, 7, 8, 10),
        'incorrect u512 add'
    );
    assert(
        f::u512_sub(mu512(4, 5, 6, 7), mu512(0, 1, 2, 3)) == mu512(4, 4, 4, 4), 'incorrect u512 sub'
    );
    let (res, _) = f::u512_sub_overflow(mu512(4, 5, 6, 7), mu512(5, 1, 2, 3));
    assert(res == mu512(max_u128, 3, 4, 4), 'incorrect u512 sub');

    let (scaled_u512, _) = f::u512_scl(mu512(4, 5, 6, 7), 9);
    assert(
        scaled_u512 == u512 { limb0: 36, limb1: 45, limb2: 54, limb3: 63, }, 'u512_scl incorrect'
    );

    let (scaled_u512, ovf) = f::u512_scl(mu512(1, 2, 3, 4), a.low);
    let (alowx1_1, alowx1_0) = f::mul_scale_sqr::u128_wide_mul(a.low, 1);
    assert(scaled_u512.limb0 == alowx1_0, 'u512_scl incorrect limb0');
    let (alowx2_1, alowx2_0) = f::mul_scale_sqr::u128_wide_mul(a.low, 2);
    assert(scaled_u512.limb1 == alowx2_0 + alowx1_1, 'u512_scl incorrect limb1');
    let (alowx3_1, alowx3_0) = f::mul_scale_sqr::u128_wide_mul(a.low, 3);
    assert(scaled_u512.limb2 == alowx2_1 + alowx3_0, 'u512_scl incorrect limb2');
    let (alowx4_1, alowx4_0) = f::mul_scale_sqr::u128_wide_mul(a.low, 4);
    assert(scaled_u512.limb3 == alowx3_1 + alowx4_0, 'u512_scl incorrect limb3');
    assert(ovf == alowx4_1, 'u512_scl incorrect limb3');

    let high_add_u512 = f::u512_high_add(mu512(4, 5, 6, 7), max_u128.into()).unwrap();

    assert(
        high_add_u512 == u512 { limb0: 4, limb1: 5, limb2: 5, limb3: 8 }, 'u512_high_add incorrect'
    );

    let high_sub_u512 = f::u512_high_sub(mu512(4, 5, 6, 7), 2).unwrap();
    assert(
        high_sub_u512 == u512 { limb0: 4, limb1: 5, limb2: 4, limb3: 7 }, 'high_sub_u512 incorrect'
    );
}
