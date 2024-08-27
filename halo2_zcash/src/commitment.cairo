mod poly; 
mod msm;
mod verifier; 

struct param {
    k: u32,
    n: u64,
    g: Array<felt252>,
    g_lagrange: Array<felt252>,
    w: felt252,
    u: felt252,
}

#[starknet::contract]
mod Commitment {
    use starknet::{ContractAddress, get_caller_address, storage_access::StorageBaseAddress};

    #[storage]
    struct Storage {
        
    }
}


#[cfg(test)]
mod test {
    #[test]
    fn example () {
        let x: felt252 = 5;
        let y: felt252 = 7;
        assert!(x != y);
    }
}