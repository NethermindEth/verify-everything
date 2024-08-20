use core::option::OptionTrait;
use core::traits::TryInto;
use core::fmt::Display;
use core::traits::Destruct;
use core::clone::Clone;
use core::traits::Into;
use core::debug::{PrintTrait, print_byte_array_as_string};
use core::array::ArrayTrait;
use core::cmp::max;

use plonk_verifier::traits::FieldShortcuts;
use plonk_verifier::traits::FieldOps;
use plonk_verifier::traits::FieldUtils;
use plonk_verifier::traits::FieldMulShortcuts;
use plonk_verifier::plonk::transcript::Keccak256Transcript;
use plonk_verifier::curve::groups::{g1, g2, AffineG1, AffineG2, AffineG2Impl};
use plonk_verifier::curve::groups::ECOperations;
use plonk_verifier::fields::{fq, Fq, Fq12, Fq12Exponentiation, Fq12Utils};
use plonk_verifier::curve::constants::{ORDER, ORDER_NZ, get_field_nz};
use plonk_verifier::plonk::types::{PlonkProof, PlonkVerificationKey, PlonkChallenge};
use plonk_verifier::plonk::transcript::{Transcript, TranscriptElement};
use plonk_verifier::curve::{u512, neg_o, sqr_nz, mul, mul_u, mul_nz, div_nz, add_nz, sub_u, sub};
use plonk_verifier::pairing::tate_bkls::{tate_pairing, tate_miller_loop};
use plonk_verifier::pairing::optimal_ate::{single_ate_pairing, ate_miller_loop};

#[generate_trait]
impl PlonkVerifier of PVerifier {
    fn verify(
        verification_key: PlonkVerificationKey, proof: PlonkProof, publicSignals: Array<u256>
    ) -> bool {
        let mut result = true;
        result = result
            && Self::is_on_curve(proof.A)
            && Self::is_on_curve(proof.B)
            && Self::is_on_curve(proof.C)
            && Self::is_on_curve(proof.Z)
            && Self::is_on_curve(proof.T1)
            && Self::is_on_curve(proof.T2)
            && Self::is_on_curve(proof.T3)
            && Self::is_on_curve(proof.Wxi)
            && Self::is_on_curve(proof.Wxiw);

        result = result
            && Self::is_in_field(proof.eval_a)
            && Self::is_in_field(proof.eval_b)
            && Self::is_in_field(proof.eval_c)
            && Self::is_in_field(proof.eval_s1)
            && Self::is_in_field(proof.eval_s2)
            && Self::is_in_field(proof.eval_zw);

        result = result
            && Self::check_public_inputs_length(
                verification_key.nPublic, publicSignals.len().into()
            );
        let mut challenges: PlonkChallenge = Self::compute_challenges(
            verification_key, proof, publicSignals.clone()
        );

        let (L, challenges) = Self::compute_lagrange_evaluations(verification_key, challenges);

        let PI = Self::compute_PI(publicSignals.clone(), L.clone());

        let R0 = Self::compute_R0(proof, challenges, PI, L[1].clone());

        let D = Self::compute_D(proof, challenges, verification_key, L[1].clone());

        let F = Self::compute_F(proof, challenges, verification_key, D);

        let E = Self::compute_E(proof, challenges, R0);

        let valid_pairing = Self::valid_pairing(proof, challenges, verification_key, E, F);
        result = result && valid_pairing;

        result
    }

    // step 1: check if the points are on the bn254 curve
    fn is_on_curve(pt: AffineG1) -> bool {
        // bn254 curve equation: y^2 = x^3 + 3
        let x_sqr = pt.x.sqr();
        let x_cubed = x_sqr.mul(pt.x);
        let lhs = x_cubed.add(fq(3));
        let rhs = pt.y.sqr();

        rhs == lhs
    }

    // step 2: check if the field element is in the field
    fn is_in_field(num: Fq) -> bool {
        // bn254 curve field:
        // 21888242871839275222246405745257275088548364400416034343698204186575808495617
        let field_p = fq(ORDER);

        num.c0 < field_p.c0
    }

    //step 3: check proof public inputs match the verification key
    fn check_public_inputs_length(len_a: u256, len_b: u256) -> bool {
        len_a == len_b
    }

    // step 4: compute challenge
    fn compute_challenges(
        verification_key: PlonkVerificationKey, proof: PlonkProof, publicSignals: Array<u256>
    ) -> PlonkChallenge {
        let mut challenges = PlonkChallenge {
            beta: fq(0),
            gamma: fq(0),
            alpha: fq(0),
            xi: fq(0),
            xin: fq(0),
            zh: fq(0),
            v1: fq(0),
            v2: fq(0),
            v3: fq(0),
            v4: fq(0),
            v5: fq(0),
            u: fq(0)
        };

        // Challenge round 2: beta and gamma
        let mut beta_transcript = Transcript::new();
        beta_transcript.add_poly_commitment(verification_key.Qm);
        beta_transcript.add_poly_commitment(verification_key.Ql);
        beta_transcript.add_poly_commitment(verification_key.Qr);
        beta_transcript.add_poly_commitment(verification_key.Qo);
        beta_transcript.add_poly_commitment(verification_key.Qc);
        beta_transcript.add_poly_commitment(verification_key.S1);
        beta_transcript.add_poly_commitment(verification_key.S2);
        beta_transcript.add_poly_commitment(verification_key.S3);

        let mut i = 0;
        while i < publicSignals.len() {
            beta_transcript.add_scalar(fq(publicSignals.at(i).clone()));
            i += 1;
        };
        beta_transcript.add_poly_commitment(proof.A);
        beta_transcript.add_poly_commitment(proof.B);
        beta_transcript.add_poly_commitment(proof.C);

        challenges.beta = beta_transcript.get_challenge();

        let mut gamma_transcript = Transcript::new();
        gamma_transcript.add_scalar(challenges.beta);
        challenges.gamma = gamma_transcript.get_challenge();

        // Challenge round 3: alpha
        let mut alpha_transcript = Transcript::new();
        alpha_transcript.add_scalar(challenges.beta);
        alpha_transcript.add_scalar(challenges.gamma);
        alpha_transcript.add_poly_commitment(proof.Z);
        challenges.alpha = alpha_transcript.get_challenge();

        // Challenge round 4: xi
        let mut xi_transcript = Transcript::new();
        xi_transcript.add_scalar(challenges.alpha);
        xi_transcript.add_poly_commitment(proof.T1);
        xi_transcript.add_poly_commitment(proof.T2);
        xi_transcript.add_poly_commitment(proof.T3);
        challenges.xi = xi_transcript.get_challenge();

        // // Challenge round 5: v
        let mut v_transcript = Transcript::new();
        v_transcript.add_scalar(challenges.xi);
        v_transcript.add_scalar(proof.eval_a);
        v_transcript.add_scalar(proof.eval_b);
        v_transcript.add_scalar(proof.eval_c);
        v_transcript.add_scalar(proof.eval_s1);
        v_transcript.add_scalar(proof.eval_s2);
        v_transcript.add_scalar(proof.eval_zw);

        challenges.v1 = v_transcript.get_challenge();
        challenges.v2 = fq(mul_nz(challenges.v1.c0, challenges.v1.c0, ORDER_NZ));
        challenges.v3 = fq(mul_nz(challenges.v2.c0, challenges.v1.c0, ORDER_NZ));
        challenges.v4 = fq(mul_nz(challenges.v3.c0, challenges.v1.c0, ORDER_NZ));
        challenges.v5 = fq(mul_nz(challenges.v4.c0, challenges.v1.c0, ORDER_NZ));

        // Challenge: u
        let mut u_transcript = Transcript::new();
        u_transcript.add_poly_commitment(proof.Wxi);
        u_transcript.add_poly_commitment(proof.Wxiw);
        challenges.u = u_transcript.get_challenge();

        challenges
    }

    // step 5,6: compute zero polynomial and calculate the lagrange evaluations
    fn compute_lagrange_evaluations(
        verification_key: PlonkVerificationKey, mut challenges: PlonkChallenge
    ) -> (Array<Fq>, PlonkChallenge) {
        let mut xin = challenges.xi;
        let mut domain_size = 1;

        let mut i = 0;
        while i < verification_key.power {
            let sqr_mod: u256 = sqr_nz(xin.c0, ORDER_NZ);
            xin = fq(sqr_mod);
            domain_size *= 2;
            i += 1;
        };

        challenges.xin = fq(xin.c0);
        challenges.zh = xin.sub(fq(1));

        let mut lagrange_evaluations: Array<Fq> = array![];
        lagrange_evaluations.append(fq(0));

        let n: Fq = fq(domain_size);
        let mut w: Fq = fq(1);

        let n_public: u32 = verification_key.nPublic.try_into().unwrap();

        let mut j = 1;
        while j <= max(1, n_public) {
            let xi_sub_w: u256 = sub_u(challenges.xi.c0, w.c0);
            let xi_mul_n: u256 = mul_nz(n.c0, xi_sub_w, ORDER_NZ);
            let w_mul_zh: u256 = mul_nz(w.c0, challenges.zh.c0, ORDER_NZ);
            let l_i = div_nz(w_mul_zh, xi_mul_n, ORDER_NZ);
            lagrange_evaluations.append(fq(l_i));

            w = fq(mul_nz(w.c0, verification_key.w, ORDER_NZ));

            j += 1;
        };

        (lagrange_evaluations, challenges)
    }

    // step 7: compute public input polynomial evaluation
    fn compute_PI(publicSignals: Array<u256>, L: Array<Fq>) -> Fq {
        let mut PI: Fq = fq(0);
        let mut i = 0;

        while i < publicSignals.len() {
            let w: u256 = publicSignals[i].clone();
            let w_mul_L: u256 = mul_nz(w, L[i + 1].c0.clone(), ORDER_NZ);
            let pi = sub(PI.c0, w_mul_L, ORDER);

            PI = fq(pi);
            i += 1;
        };

        PI
    }

    // step 8: compute r constant
    fn compute_R0(proof: PlonkProof, challenges: PlonkChallenge, PI: Fq, L1: Fq) -> Fq {
        let e1: u256 = PI.c0;
        let e2: u256 = mul_nz(L1.c0, sqr_nz(challenges.alpha.c0, ORDER_NZ), ORDER_NZ);

        let mut e3a = add_nz(
            proof.eval_a.c0, mul_nz(challenges.beta.c0, proof.eval_s1.c0, ORDER_NZ), ORDER_NZ
        );
        e3a = add_nz(e3a, challenges.gamma.c0, ORDER_NZ);

        let mut e3b = add_nz(
            proof.eval_b.c0, mul_nz(challenges.beta.c0, proof.eval_s2.c0, ORDER_NZ), ORDER_NZ
        );
        e3b = add_nz(e3b, challenges.gamma.c0, ORDER_NZ);

        let mut e3c = add_nz(proof.eval_c.c0, challenges.gamma.c0, ORDER_NZ);

        let mut e3 = mul_nz(mul_nz(e3a, e3b, ORDER_NZ), e3c, ORDER_NZ);
        e3 = mul_nz(e3, proof.eval_zw.c0, ORDER_NZ);
        e3 = mul_nz(e3, challenges.alpha.c0, ORDER_NZ);

        let r0 = sub(sub(e1, e2, ORDER), e3, ORDER);

        fq(r0)
    }

    // step 9: Compute first part of batched polynomial commitment D
    fn compute_D(
        proof: PlonkProof, challenges: PlonkChallenge, vk: PlonkVerificationKey, l1: Fq
    ) -> AffineG1 {
        let mut d1 = vk.Qm.multiply((mul_nz(proof.eval_a.c0, proof.eval_b.c0, ORDER_NZ)));
        d1 = d1.add(vk.Ql.multiply(proof.eval_a.c0));
        d1 = d1.add(vk.Qr.multiply(proof.eval_b.c0));
        d1 = d1.add(vk.Qo.multiply(proof.eval_c.c0));
        d1 = d1.add(vk.Qc);

        let betaxi = mul_nz(challenges.beta.c0, challenges.xi.c0, ORDER_NZ);
        let mut d2a1 = add_nz(proof.eval_a.c0, betaxi, ORDER_NZ);
        d2a1 = add_nz(d2a1, challenges.gamma.c0, ORDER_NZ);

        let mut d2a2 = mul_nz(betaxi, vk.k1, ORDER_NZ);
        d2a2 = add_nz(proof.eval_b.c0, d2a2, ORDER_NZ);
        d2a2 = add_nz(d2a2, challenges.gamma.c0, ORDER_NZ);

        let mut d2a3 = mul_nz(betaxi, vk.k2, ORDER_NZ);
        d2a3 = add_nz(proof.eval_c.c0, d2a3, ORDER_NZ);
        d2a3 = add_nz(d2a3, challenges.gamma.c0, ORDER_NZ);

        let d2a = mul_nz(
            mul_nz(mul_nz(d2a1, d2a2, ORDER_NZ), d2a3, ORDER_NZ), challenges.alpha.c0, ORDER_NZ
        );

        let d2b = mul_nz(l1.c0, sqr_nz(challenges.alpha.c0, ORDER_NZ), ORDER_NZ);

        let d2 = proof.Z.multiply(add_nz(add_nz(d2a, d2b, ORDER_NZ), challenges.u.c0, ORDER_NZ));

        let d3a = add_nz(
            add_nz(
                proof.eval_a.c0, mul_nz(challenges.beta.c0, proof.eval_s1.c0, ORDER_NZ), ORDER_NZ
            ),
            challenges.gamma.c0,
            ORDER_NZ
        );

        let d3b = add_nz(
            add_nz(
                proof.eval_b.c0, mul_nz(challenges.beta.c0, proof.eval_s2.c0, ORDER_NZ), ORDER_NZ
            ),
            challenges.gamma.c0,
            ORDER_NZ
        );

        let d3c = mul_nz(
            mul_nz(challenges.alpha.c0, challenges.beta.c0, ORDER_NZ), proof.eval_zw.c0, ORDER_NZ
        );

        let d3 = vk.S3.multiply(mul_nz(mul_nz(d3a, d3b, ORDER_NZ), d3c, ORDER_NZ));

        let d4low = proof.T1;
        let d4mid = proof.T2.multiply(challenges.xin.c0);
        let d4high = proof.T3.multiply(sqr_nz(challenges.xin.c0, ORDER_NZ));
        let mut d4 = d4mid.add(d4high);
        d4 = d4.add(d4low);
        d4 = d4.multiply(challenges.zh.c0);

        let mut d = d1.add(d2);
        d = d.add(d3.neg());
        d = d.add(d4.neg());

        d
    }

    // step 10: Compute full batched polynomial commitment F
    fn compute_F(
        proof: PlonkProof, challenges: PlonkChallenge, vk: PlonkVerificationKey, D: AffineG1
    ) -> AffineG1 {
        let mut v1a = proof.A.multiply(challenges.v1.c0);
        let res_add_d = v1a.add(D);

        let v2b = proof.B.multiply(challenges.v2.c0);
        let res_add_v2b = res_add_d.add(v2b);

        let v3c = proof.C.multiply(challenges.v3.c0);
        let res_add_v3c = res_add_v2b.add(v3c);

        let v4s1 = vk.S1.multiply(challenges.v4.c0);
        let res_add_v4s1 = res_add_v3c.add(v4s1);

        let v5s2 = vk.S2.multiply(challenges.v5.c0);
        let res = res_add_v4s1.add(v5s2);

        res
    }

    // step 11: Compute group-encoded batch evaluation E
    fn compute_E(proof: PlonkProof, challenges: PlonkChallenge, r0: Fq) -> AffineG1 {
        let mut res: AffineG1 = g1(1, 2);
        let neg_r0 = neg_o(r0.c0);
        let mut e = add_nz(neg_r0, mul_nz(challenges.v1.c0, proof.eval_a.c0, ORDER_NZ), ORDER_NZ);

        e = add_nz(e, mul_nz(challenges.v2.c0, proof.eval_b.c0, ORDER_NZ), ORDER_NZ);
        e = add_nz(e, mul_nz(challenges.v3.c0, proof.eval_c.c0, ORDER_NZ), ORDER_NZ);
        e = add_nz(e, mul_nz(challenges.v4.c0, proof.eval_s1.c0, ORDER_NZ), ORDER_NZ);
        e = add_nz(e, mul_nz(challenges.v5.c0, proof.eval_s2.c0, ORDER_NZ), ORDER_NZ);
        e = add_nz(e, mul_nz(challenges.u.c0, proof.eval_zw.c0, ORDER_NZ), ORDER_NZ);

        res = res.multiply(e);

        res
    }

    //step 12: Elliptic Curve Pairing: Batch validate all evaluations
    fn valid_pairing(
        proof: PlonkProof,
        challenges: PlonkChallenge,
        vk: PlonkVerificationKey,
        E: AffineG1,
        F: AffineG1
    ) -> bool {
        let mut A1 = proof.Wxi;

        let Wxiw_mul_u = proof.Wxiw.multiply(challenges.u.c0);
        A1 = A1.add(Wxiw_mul_u);

        let mut B1 = proof.Wxi.multiply(challenges.xi.c0);
        let s = mul_nz(mul_nz(challenges.u.c0, challenges.xi.c0, ORDER_NZ), vk.w, ORDER_NZ);

        let Wxiw_mul_s = proof.Wxiw.multiply(s);
        B1 = B1.add(Wxiw_mul_s);

        B1 = B1.add(F);

        B1 = B1.add(E.neg());

        let g2_one = AffineG2Impl::one();

        let e_A1_vk_x2 = single_ate_pairing(A1, vk.X_2);
        let e_B1_g2_1 = single_ate_pairing(B1, g2_one);

        let res: bool = e_A1_vk_x2.c0 == e_B1_g2_1.c0;

        res
    }
}
