use core::traits::Add;
use core::num::traits::Zero;
use core::cmp::max;

pub fn sum_array<
    T, impl TAdd: Add<T>, impl TZero: Zero<T>, impl TDrop: Drop<T>, impl TCopy: Copy<T>
>(
    arr: Span<T>
) -> T {
    let mut sum = TZero::zero();
    let mut len = arr.len();
    while len > 0 {
        len -= 1;
        sum = sum + *arr.get(len).unwrap().unbox();
    };

    sum
}

pub fn max_array<
    T,
    impl TZero: Zero<T>,
    impl TCopy: Copy<T>,
    impl TPartialOrd: PartialOrd<T>,
    impl TDrop: Drop<T>
>(
    arr: Span<T>
) -> T {
    let mut max = TZero::zero();
    let mut len = arr.len();
    while len > 0 {
        len -= 1;
        let item = *arr.get(len).unwrap().unbox();
        if item > max {
            max = item;
        }
    };

    max
}

pub fn min_array<
    T,
    impl TZero: Zero<T>,
    impl TCopy: Copy<T>,
    impl TPartialOrd: PartialOrd<T>,
    impl TDrop: Drop<T>
>(
    arr: Span<T>
) -> T {
    let mut min = TZero::zero();
    let mut len = arr.len();
    while len > 0 {
        len -= 1;
        let item = *arr.get(len).unwrap().unbox();
        if item < min {
            min = item;
        }
    };

    min
}

pub fn pow<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>, impl TMul: Mul<T>>(base: T, exp: u32) -> T {
    // iterative squaring
    let mut result = base;
    let mut exp = exp;
    while exp > 1 {
        if exp % 2 == 0 {
            result = result * result;
            exp = exp / 2;
        } else {
            result = result * base;
            exp = exp - 1;
        }
    };
    result
}

pub fn shift_left(x: usize, shift: u32) -> usize {
    x * pow(2, shift)
}

pub fn shift_right(x: usize, shift: u32) -> usize {
    x / pow(2, shift)
}

/// helper function to calculate the log base 2 of a number
pub fn log2_strict(x: usize) -> usize {
    let mut y = 0;
    let mut z = x;
    while z > 1 {
        z = z / 2;
        y = y + 1;
    };
    y
}
