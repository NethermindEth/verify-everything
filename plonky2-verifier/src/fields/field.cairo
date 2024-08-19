pub trait F<T> {
    fn TWO_ADICITY() -> usize;
    fn CHARACTERISTIC_TWO_ADICITY() -> usize;
    fn MULTIPLICATIVE_GROUP_GENERATOR() -> T;
    fn POWER_OF_TWO_GENERATOR() -> T;
    fn exp_power_of_2(self: @T, power_log: usize) -> T;
    fn exp_u64(self: @T, exp: u64) -> T;
    fn primitive_root_of_unity(n_log: usize) -> T;
}
