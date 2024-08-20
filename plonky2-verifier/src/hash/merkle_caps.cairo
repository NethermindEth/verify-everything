use core::traits::TryInto;
use core::clone::Clone;
use core::array::ArrayTrait;
use core::array::Span;
use core::array::SpanTrait;
use core::box::BoxTrait;
use core::option::OptionTrait;
use core::to_byte_array::FormatAsByteArray;
use core::traits::Into;
use plonky2_verifier::fields::goldilocks::GoldilocksTrait;
use plonky2_verifier::fields::goldilocks::{Goldilocks, gl};
use plonky2_verifier::fields::utils::{log2_strict};
use plonky2_verifier::hash::poseidon::{hash_two_to_one};
use plonky2_verifier::hash::structure::{HashOut, HashOutImpl};
use plonky2_verifier::hash::poseidon::{hash_no_pad};

/// The Merkle cap of height `h` of a Merkle tree is the `h`-th layer (from the root) of the tree.
/// It can be used in place of the root to verify Merkle paths, which are `h` elements shorter.
#[derive(Drop, Clone, Debug)]
pub struct MerkleCaps {
    pub data: Array<HashOut>
}

#[derive(Drop, Debug)]
pub struct MerkleProof {
    pub siblings: Array<HashOut>,
}

#[generate_trait]
pub impl MerkleCapsImpl of MerkleCapsTrait {
    fn default() -> MerkleCaps {
        MerkleCaps { data: array![] }
    }

    fn len(self: @MerkleCaps) -> usize {
        self.data.len()
    }

    fn is_empty(self: @MerkleCaps) -> bool {
        self.data.is_empty()
    }

    fn height(self: @MerkleCaps) -> usize {
        log2_strict(self.len())
    }

    fn verify(self: @MerkleCaps, index: usize, leaf: HashOut, proof: @MerkleProof,) -> bool {
        let mut node = leaf;

        if leaf.elements.len() > 4 {
            node = hash_no_pad(leaf.elements)
        }

        let mut index = index;

        let mut i = 0;
        let len = proof.siblings.len();
        while i < len {
            let sibling = *proof.siblings.get(i).unwrap().unbox();
            if index % 2 == 0 {
                node = hash_two_to_one(node, sibling);
            } else {
                node = hash_two_to_one(sibling, node);
            }
            index /= 2;
            i += 1;
        };

        node == *self.data[index]
    }
}

#[derive(Drop, Debug)]
pub struct MerkleTree {
    /// The data in the leaves of the Merkle tree.
    pub leaves: Array<HashOut>, // leaves are assumed to be formatted as hash ouputs 
    pub digests: Array<HashOut>,
    pub cap: MerkleCaps,
}


#[generate_trait]
impl MerkleTreeImpl of MerkleTreeTrait {
    fn default() -> MerkleTree {
        MerkleTree { leaves: array![], digests: array![], cap: MerkleCapsImpl::default(), }
    }

    fn new(leaves: Array<HashOut>, cap_size: usize) -> MerkleTree {
        let num_leaves = leaves.len();
        let mut digests: Array<HashOut> = array![];
        let mut cap: Array<HashOut> = array![];

        // Populate the leaves and compute hashes for internal nodes
        let mut i = 0;

        let l = leaves.clone();

        // Compute the first level of internal nodes
        while i < num_leaves {
            let hash_val = hash_two_to_one(*l[i], *l[i + 1]); // 2 to one hash
            digests.append(hash_val);
            i += 2;
        };

        // initial level size is half the number of leaves since each pair of leaves is hashed to one internal node
        let mut level_size = num_leaves / 2;
        // index of the first node in the current level in the digests array
        let mut start_idx = 0;

        // compute the next levels of internal nodes
        loop {
            i = 0;
            // loop through the current level of internal nodes and compute hash(l, r) for each pair of nodes
            while i < level_size {
                let hash_val = hash_two_to_one(
                    *digests[start_idx + i], *digests[start_idx + i + 1]
                );
                if (level_size / 2 == cap_size) {
                    // cap is the next level - which means we store
                    // the hashes of the level being computed in cap instead of digests
                    cap.append(hash_val);
                } else {
                    digests.append(hash_val);
                }
                i += 2;
            };

            start_idx += level_size;
            level_size /= 2;

            if level_size == cap_size {
                break;
            }
        };

        MerkleTree { leaves: leaves, digests: digests, cap: MerkleCaps { data: cap } }
    }

    fn prove(self: @MerkleTree, index: usize) -> MerkleProof {
        // includes the sibling of the leaf and the siblings of the nodes on the path to the cap level
        let mut proof: Array<HashOut> = array![];
        let mut i = index;

        // add sibling of leaf to proof
        if i % 2 == 0 {
            proof.append(*self.leaves[i + 1]);
        } else {
            proof.append(*self.leaves[i - 1]);
        };

        // levels from the root to the cap level
        let cap_height = self.cap.height();
        // initialize to max number of levels in a normal merkle proof
        let mut remaining_levels = log2_strict(self.leaves.len())
            - 1; // -1 to account for the level of the leaf
        let mut level_size = self.leaves.len() / 2;
        let mut start_idx = 0; // index of the first node in the current level in the digests array

        // add siblings of nodes on the path to the cap to proof
        loop {
            if remaining_levels == cap_height { // reached the cap level, no need to calculate up to the root
                break;
            }

            i = i / 2; // parent index
            if i % 2 == 0 { // left child
                proof.append(*self.digests[start_idx + i + 1]);
            } else {
                proof.append(*self.digests[start_idx + i - 1]);
            };

            // move to the next level
            start_idx += level_size;
            level_size /= 2;
            remaining_levels -= 1;
        };

        MerkleProof { siblings: proof }
    }
}
#[cfg(test)]
mod tests {
    use plonky2_verifier::hash::merkle_caps::MerkleCapsTrait;
    use core::traits::Into;
    use super::{gl, HashOut, MerkleTreeImpl, MerkleCapsImpl, MerkleTree, HashOutImpl};

    fn h(x: u64) -> HashOut {
        HashOutImpl::new(array![gl(x), gl(0), gl(0), gl(0)].span())
    }

    fn make_sample_tree() -> MerkleTree {
        MerkleTreeImpl::new(array![h(1), h(2), h(3), h(4), h(5), h(6), h(7), h(8),], 2)
    }

    #[test]
    fn test_init() {
        let tree = make_sample_tree();
        // let tree = make_sample_tree();
        assert_eq!(tree.leaves.len(), 8);
        assert_eq!(tree.digests.len(), 4);
        assert_eq!(tree.cap.len(), 2);
    }

    #[test]
    fn test_prove() {
        let tree = make_sample_tree();
        let proof = tree.prove(0);
        assert_eq!(proof.siblings.len(), 2);
    }

    #[test]
    fn test_should_verify_valid_proof() {
        let tree = make_sample_tree();
        let proof = tree.prove(5);
        let verified = tree.cap.verify(5, h(6), @proof);
        assert_eq!(verified, true);
    }
    #[test]
    fn test_should_verify_valid_proof2() {
        let tree = make_sample_tree();
        let proof = tree.prove(1); // index of 1
        let verified = tree.cap.verify(1, h(2), @proof);
        assert_eq!(verified, true);
    }
    #[test]
    fn test_should_not_verify_invalid_proof() {
        let tree = make_sample_tree();
        let proof = tree.prove(5);
        let verified = tree.cap.verify(5, h(7), @proof);
        assert_eq!(verified, false);
    }
}

