use core::array::ArrayTrait;
use plonky2_verifier::hash::merkle_caps::{MerkleCaps, MerkleProof};
use plonky2_verifier::fields::goldilocks_quadratic::GoldilocksQuadratic;
use plonky2_verifier::fields::goldilocks::Goldilocks;
use plonky2_verifier::hash::poseidon::hash_no_pad;
use plonky2_verifier::hash::structure::HashOut;
use plonky2_verifier::fri::structure::{FriChallenges, FriOpenings, FriOpeningBatch};
use plonky2_verifier::plonk::circuit_data::{CommonCircuitData, CommonCircuitDataImpl};
use plonky2_verifier::plonk::challenge::{Challenger, ChallengerImpl, ChallengerTrait};

#[derive(Drop, Debug)]
pub struct OpeningSet {
    pub constants: Array<GoldilocksQuadratic>,
    pub plonk_sigmas: Array<GoldilocksQuadratic>,
    pub wires: Array<GoldilocksQuadratic>,
    pub plonk_zs: Array<GoldilocksQuadratic>,
    pub plonk_zs_next: Array<GoldilocksQuadratic>,
    pub partial_products: Array<GoldilocksQuadratic>,
    pub quotient_polys: Array<GoldilocksQuadratic>,
    pub lookup_zs: Array<GoldilocksQuadratic>,
    pub lookup_zs_next: Array<GoldilocksQuadratic>,
}

#[generate_trait]
pub impl OpeningSetImpl of OpeningSetTrait {
    fn to_fri_openings(self: @OpeningSet) -> FriOpenings {
        let mut values = array![];
        values.append_span(self.constants.span());
        values.append_span(self.plonk_sigmas.span());
        values.append_span(self.wires.span());
        values.append_span(self.plonk_zs.span());
        values.append_span(self.partial_products.span());
        values.append_span(self.quotient_polys.span());

        let opening_batch = FriOpeningBatch { values: values.span() };
        let zeta_next_batch = FriOpeningBatch { values: self.plonk_zs_next.span() };

        FriOpenings { batches: array![opening_batch, zeta_next_batch] }
    }
}

#[derive(Drop, Debug)]
pub struct FriInitialTreeProof {
    pub evals_proofs: Array<(Array<Goldilocks>, MerkleProof)>
}

#[derive(Drop, Debug)]
pub struct FriQueryStep {
    pub evals: Array<GoldilocksQuadratic>,
    pub merkle_proof: MerkleProof
}

#[derive(Drop, Debug)]
pub struct FriQueryRound {
    pub initial_trees_proof: FriInitialTreeProof,
    pub steps: Array<FriQueryStep>,
}

#[derive(Drop, Debug)]
pub struct PolynomialCoeffs<F> {
    pub coeffs: Array<F>,
}

#[derive(Drop, Debug)]
pub struct FriProof {
    pub commit_phase_merkle_caps: Array<MerkleCaps>,
    pub query_round_proofs: Array<FriQueryRound>,
    pub final_poly: PolynomialCoeffs<GoldilocksQuadratic>,
    pub pow_witness: Goldilocks,
}

#[derive(Drop, Debug)]
pub struct Proof {
    pub wires_cap: MerkleCaps,
    pub plonk_zs_partial_products_cap: MerkleCaps,
    pub quotient_polys_cap: MerkleCaps,
    pub openings: OpeningSet,
    pub opening_proof: FriProof
}

#[derive(Drop, Debug, PartialEq)]
pub struct ProofChallenges {
    pub plonk_betas: Span<Goldilocks>,
    pub plonk_gammas: Span<Goldilocks>,
    pub plonk_alphas: Span<Goldilocks>,
    pub plonk_deltas: Span<Goldilocks>,
    pub plonk_zeta: GoldilocksQuadratic,
    pub fri_challenges: FriChallenges,
}

#[derive(Drop, Debug)]
pub struct ProofWithPublicInputs {
    pub proof: Proof,
    pub public_inputs: Array<Goldilocks>,
}

#[generate_trait]
pub impl ProofWithPublicInputsImpl of ProofWithPublicInputsTrait {
    fn get_public_inputs_hash(self: @ProofWithPublicInputs) -> HashOut {
        hash_no_pad(self.public_inputs.span())
    }

    /// Computes all Fiat-Shamir challenges used in the Plonk proof.
    fn get_challenges(
        self: @ProofWithPublicInputs,
        public_inputs_hash: @HashOut,
        circuit_digest: @HashOut,
        common_data: @CommonCircuitData
    ) -> ProofChallenges {
        let Proof { wires_cap,
        plonk_zs_partial_products_cap,
        quotient_polys_cap,
        openings,
        opening_proof: FriProof { commit_phase_merkle_caps, final_poly, pow_witness, .. }, } =
            self
            .proof;

        let config = common_data.config;
        let num_challenges = *config.num_challenges;

        println!("num_challenges: {:?}", num_challenges);

        let mut challenger = ChallengerImpl::new();

        // observer the instance
        challenger.observe_hash(circuit_digest);
        challenger.observe_hash(public_inputs_hash);
        challenger.observe_cap(wires_cap);
        println!("input buffer: {:?}", challenger.input_buffer);

        let plonk_betas = challenger.get_n_challenges(num_challenges);

        println!("plonk betas, {:?}", plonk_betas);

        let plonk_gammas = challenger.get_n_challenges(num_challenges);
        let plonk_deltas = array![].span(); // todo: consider lookups

        challenger.observe_cap(plonk_zs_partial_products_cap);
        let plonk_alphas = challenger.get_n_challenges(num_challenges);

        challenger.observe_cap(quotient_polys_cap);
        let plonk_zeta = challenger.get_extension_challenge();

        challenger.observe_openings(@openings.to_fri_openings());

        ProofChallenges {
            plonk_betas,
            plonk_gammas,
            plonk_alphas,
            plonk_deltas,
            plonk_zeta,
            fri_challenges: challenger
                .fri_challenges(
                    commit_phase_merkle_caps.span(),
                    final_poly,
                    *pow_witness,
                    common_data.degree_bits(),
                    config.fri_config.clone(),
                ),
        }
    }
}
