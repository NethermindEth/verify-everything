// use starknet::ContractAddress;

// #[starknet::contract]
// mod PlonkVerifier {
//     use starknet::ContractAddress;
//     use starknet::get_caller_address;
// fn verify_proof() {}
// fn check_input() {}
// fn calculate_challenges() {}
// fn calculate_lagrange() {}
// fn calculate_pi() {}
// fn calculate_r0() {}
// fn calculate_d() {}
// fn calculate_f() {}
// fn calculate_e() {}
// fn check_pairing() {}

// constants 
// const W1: u256 = 4158865282786404163413953114870269622875596290766033564087307867933865333818;
// const Q: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
// const QF: u256 = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
// const G1x: felt252 = 1;
// const G1y: felt252 = 2;

// #[storage] // need to be modified
// struct Storage {
//     owner: ContractAddress,
// }
// #[derive(Drop)]
// struct Proof {
//     A: Array<felt252>,
//     B: Array<felt252>,
//     C: Array<felt252>,
//     Z: Array<felt252>,
//     T1: Array<felt252>,
//     T2: Array<felt252>,
//     T3: Array<felt252>,
//     Wxi: Array<felt252>,
//     Wxiw: Array<felt252>,
//     eval_a: felt252,
//     eval_b: felt252,
//     eval_c: felt252,
//     eval_s1: felt252,
//     eval_s2: felt252,
//     eval_zw: felt252,
// }
// }

#[starknet::interface]
trait IPlonkVerifier<TContractState> {
    fn set(ref self: TContractState, x: u128);
    fn get(self: @TContractState) -> u128;
    fn verify_proof(ref self: TContractState);
    fn check_input(ref self: TContractState);
}

#[starknet::contract]
mod PlonkVerifier {
    use starknet::get_caller_address;
    use starknet::ContractAddress;

    // constants 
    const W1: u256 = 4158865282786404163413953114870269622875596290766033564087307867933865333818;
    const Q: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    const QF: u256 = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    const G1x: felt252 = 1;
    const G1y: felt252 = 2;

    #[storage]
    struct Storage {
        stored_data: u128
    }

    #[abi(embed_v0)]
    impl PlonkVerifier of super::IPlonkVerifier<ContractState> {
        fn set(ref self: ContractState, x: u128) {
            self.stored_data.write(x);
        }
        fn get(self: @ContractState) -> u128 {
            self.stored_data.read()
        }
        fn verify_proof(ref self: ContractState) {}
        fn check_input(ref self: ContractState) {}
    }
}
