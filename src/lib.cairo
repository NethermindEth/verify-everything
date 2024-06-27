use plonky2_verifier::hash::poseidon::hash_n_to_m_no_pad;
use plonky2_verifier::fields::goldilocks::gl;
mod fields;
mod hash;

fn main() {
}

#[cfg(test)]
mod tests {
    
    use super::{hash_n_to_m_no_pad, gl};


    #[test]
    fn test() {
        let input = array![gl(1)];
        let the_hash = hash_n_to_m_no_pad(input.span(), 1);
        println!("hash: {:?}", the_hash);
    }
}