use core::traits::Into;
use core::result::ResultTrait;
use core::box::BoxTrait;
use core::option::OptionTrait;
use plonky2_verifier::fri::structure::FriParamsTrait;
use plonky2_verifier::fri::structure::{
    FriInstanceInfo, FriOpenings, FriChallenges, FriOracleInfo, FriPolynomialInfo, FriBatchInfo,
    FriReductionStrategy, FriConfig, FriParams
};
use plonky2_verifier::hash::merkle_caps::{MerkleCaps, MerkleCapsImpl, MerkleProof};
use plonky2_verifier::hash::structure::{HashOut, HashOutImpl};
use plonky2_verifier::plonk::proof::{FriProof, FriInitialTreeProofTrait};
use plonky2_verifier::fri::structure::{PrecomputedReducedOpenings, PrecomputedReducedOpeningsImpl};
use plonky2_verifier::plonk::proof::{FriQueryRound, FriInitialTreeProof};
use plonky2_verifier::plonk::circuit_data::{
    CommonCircuitData, CommonCircuitDataImpl, CommonCircuitDataTrait
};
use plonky2_verifier::fields::utils::{log2_strict, reverse_bits};
use plonky2_verifier::fields::goldilocks::{GoldilocksField, Goldilocks};
use plonky2_verifier::fields::goldilocks_quadratic::{GoldilocksQuadratic};
use plonky2_verifier::fri::structure::{ReducingFactor, ReducingFactorImpl};

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

    let precomputed_reduced_evals = PrecomputedReducedOpeningsImpl::from_os_and_alpha(
        openings, challenges.fri_alpha
    );

    let num_query_rounds = *params.config.num_query_rounds;
    let mut i = 0;
    while i < num_query_rounds {
        let mut x_index = *challenges.fri_query_indices.get(i).unwrap().unbox();
        let round_proof = proof.query_round_proofs.get(i).unwrap().unbox();
        fri_verifier_query_round(
            instance,
            challenges,
            @precomputed_reduced_evals,
            initial_merkle_caps,
            proof,
            ref x_index,
            n,
            round_proof,
            params
        )
            .unwrap();
        i += 1;
    }
}

pub fn fri_verifier_query_round(
    instance: @FriInstanceInfo,
    challenges: @FriChallenges,
    precomputed_reduced_evals: @PrecomputedReducedOpenings,
    initial_merkle_caps: Span<MerkleCaps>,
    proof: @FriProof,
    ref x_index: usize,
    n: usize,
    round_proof: @FriQueryRound,
    params: @FriParams,
) -> Result<(), ()> {
    // fri_verify_initial_proof(x_index, round_proof.initial_trees_proof, initial_merkle_caps)?;

    let log_n = log2_strict(n);
    let mut subgroup_x = GoldilocksField::MULTIPLICATIVE_GROUP_GENERATOR()
        * GoldilocksField::primitive_root_of_unity(log_n)
            .exp_u64(reverse_bits(x_index, log_n).into());

    let mut old_eval = fri_combine_initial(
        instance,
        round_proof.initial_trees_proof,
        *challenges.fri_alpha,
        subgroup_x,
        precomputed_reduced_evals,
        params,
    );

    

    Result::Ok(())
}

pub fn fri_verify_initial_proof(
    x_index: usize, proof: @FriInitialTreeProof, initial_merkle_caps: Span<MerkleCaps>
) -> Result<(), ()> {
    assert_eq!(proof.evals_proofs.len(), initial_merkle_caps.len());
    let len = initial_merkle_caps.len();
    let mut i = 0;
    let mut result = Result::Ok(());
    while i < len {
        let (evals, merkle_proof) = proof.evals_proofs.get(i).unwrap().unbox();
        let cap = initial_merkle_caps.get(i).unwrap().unbox();
        let is_valid = cap.verify(x_index, HashOut { elements: evals.span() }, merkle_proof);
        if !is_valid {
            result = Result::Err(());
            break;
        }
        i += 1;
    };
    result
}

fn fri_combine_initial(
    instance: @FriInstanceInfo,
    proof: @FriInitialTreeProof,
    alpha: GoldilocksQuadratic,
    subgroup_x: Goldilocks,
    precomputed_reduced_evals: @PrecomputedReducedOpenings,
    params: @FriParams,
) -> GoldilocksQuadratic {
    let subgroup_x = GoldilocksQuadratic { a: subgroup_x, b: Goldilocks { inner: 0 } };
    let mut alpha = ReducingFactorImpl::new(alpha);
    let mut sum = GoldilocksQuadratic { a: Goldilocks { inner: 0 }, b: Goldilocks { inner: 0 } };

    let mut i = 0;
    loop {
        if i >= instance.batches.len() {
            break;
        }
        let batch = instance.batches.get(i).unwrap().unbox();
        let reduced_openings = precomputed_reduced_evals.reduced_openings_at_point[i];

        let FriBatchInfo { point, polynomials } = batch;
        let mut evals = array![];
        let mut j = 0;
        let len = polynomials.len();
        while j < len {
            let p: FriPolynomialInfo = *polynomials[j];
            let oracle: FriOracleInfo = *instance.oracles.get(p.oracle_index).unwrap().unbox();
            let poly_blinding: bool = oracle.blinding;
            let salted = *params.hiding && poly_blinding;
            let eval = proof.unsalted_eval(p.oracle_index, p.polynomial_index, salted);
            evals.append(eval);
            j += 1;
        };

        let reduced_evals = alpha.reduce(evals.span());
        let numerator = reduced_evals - *reduced_openings;
        let denominator = subgroup_x - *point;
        sum = alpha.shift(sum);
        sum = sum + (numerator / denominator);

        i += 1;
    };

    sum
}

#[cfg(test)]
pub mod tests {
    use plonky2_verifier::plonk::circuit_data::CommonCircuitDataTrait;
    use plonky2_verifier::plonk::proof::ProofWithPublicInputsTrait;
    use super::{verify_fri_proof};
    use plonky2_verifier::plonk::constants::sample_proof_1;
    use plonky2_verifier::plonk::proof::{OpeningSetTrait};

    #[test]
    #[available_gas(200000000000)]
    fn test_fri_query_round() {
        let proof_with_pis = sample_proof_1::get_proof_with_public_inputs();
        let common_data = sample_proof_1::get_common_data();
        let verifier_only_data = sample_proof_1::get_verifier_only_data();
        let circuit_digest = verifier_only_data.circuit_digest;
        let public_inputs_hash = proof_with_pis.get_public_inputs_hash();
        let challenges = proof_with_pis
            .get_challenges(@public_inputs_hash, @circuit_digest, @common_data);

        let merkle_caps = array![
            verifier_only_data.constants_sigmas_cap,
            proof_with_pis.proof.wires_cap,
            proof_with_pis.proof.plonk_zs_partial_products_cap,
            proof_with_pis.proof.quotient_polys_cap
        ];

        verify_fri_proof(
            @common_data.get_fri_instance(challenges.plonk_zeta),
            @proof_with_pis.proof.openings.to_fri_openings(),
            @challenges.fri_challenges,
            merkle_caps.span(),
            @proof_with_pis.proof.opening_proof,
            @common_data.fri_params
        );
    }
}

