use core::traits::Into;
use core::array::ArrayTrait;


#[derive(Clone, Drop, Debug)]
struct Verifier {}

#[generate_trait]
impl PlonkVerifier of PVerifier {
    fn verify_proof() {}
    fn check_field(num: u256, p: u256) -> bool {
        num >= 0 && num < p
    }
    fn check_input() {// PlonkVerifier::check_field();
    // PlonkVerifier::check_field((pEval_c));
    // PlonkVerifier::check_field((pEval_s1));
    // PlonkVerifier::check_field((pEval_s2));
    // PlonkVerifier::check_field((pEval_zw));
    }
}

#[cfg(test)]
mod tests {
    use super::PlonkVerifier;
    use core::traits::Into;
    use core::traits::RemEq;
    #[test]
    fn test_check_field() {
        let p = 13;
        assert_eq!(PlonkVerifier::check_field(5, p), true);
        assert_eq!(PlonkVerifier::check_field(0, p), true);
        assert_eq!(PlonkVerifier::check_field(16, p), false);
    }
}
