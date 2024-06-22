use core::poseidon::poseidon_hash_span;

mod fields;
mod hash;

fn main() {
}

#[cfg(test)]
mod tests {
    
    use super::{poseidon_hash_span};

    #[test]
    fn test() {
        let input = array![1];
        let the_hash = poseidon_hash_span(input.span());
        println!("{:?}", the_hash);
    }
}