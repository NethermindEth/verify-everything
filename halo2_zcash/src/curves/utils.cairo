
pub const BITS128_MASK_64: u128 = 0x0000000000000000FFFFFFFFFFFFFFFF_u128;
pub const BITS64_2_POW_63: u64 = 0x8000000000000000_u64;
pub const BITS128_2_POW_64: u128 = 0x10000000000000000_u128; 

// Modulus Wrapping Functions 
pub fn wrapping_sub_u64(a: u64, b: u64) -> u64 {
    if a >= b {
        a - b
    } else {
        0xFFFFFFFFFFFFFFFF_u64 - (b - a) + 1
    }
}

pub fn wrapping_sub_u128(a: u128, b: u128) -> u128 {
    if a >= b {
        a - b
    } else {
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128 - (b - a) + 1
    }
}

pub fn wrapping_mul_u64(a: u64, b: u64) -> u64 {
    let ret: u128 = a.into() * b.into();
    (ret & BITS128_MASK_64).try_into().unwrap()
}

pub fn bti(lhs: bool) -> u64 {
    let mut x: u64 = 0;
    if lhs {x = 1;}
    x
}