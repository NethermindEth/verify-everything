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

mod verifier;
