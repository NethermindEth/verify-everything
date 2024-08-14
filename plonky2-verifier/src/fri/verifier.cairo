use plonky2_verifier::fri::structure::FriParamsTrait;
use plonky2_verifier::fri::structure::{
    FriInstanceInfo, FriOpenings, FriChallenges, FriOracleInfo, FriPolynomialInfo, FriBatchInfo,
    FriReductionStrategy, FriConfig, FriParams
};
use plonky2_verifier::merkle::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::plonk::proof::{FriProof};

pub fn verify_fri_proof(
    instance: @FriInstanceInfo,
    openings: @FriOpenings,
    challenges: @FriChallenges,
    initial_merkle_caps: Span<MerkleCaps>,
    proof: @FriProof,
    params: @FriParams,
) {
    // todo: verify the proof shape

    // size of the lde domain
    let n = params.lde_size();
// todo: verify pow witness
// todo: assert_eq!(*params.config.num_query_rounds, proof.query_round_proofs.len());

}
