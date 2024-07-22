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
use plonky2_verifier::hash::poseidon::hash_n_to_m_no_pad;

#[derive(Drop, Debug)]
pub struct MerkleCaps {
    pub data: Array<Goldilocks>
}


#[generate_trait]
impl MerkleCapsImpl of MerkleCapsTrait {
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

    fn flatten(self: @MerkleCaps) -> Array<Goldilocks> {
        self.data.clone()
    }
}

#[derive(Drop, Debug)]
pub struct MerkleTree {
    pub leaves: Span<Goldilocks>,
    pub digests: Span<Goldilocks>,
    pub cap: MerkleCaps,
}


#[generate_trait]
impl MerkleTreeImpl of MerkleTreeTrait {
    fn default() -> MerkleTree {
        MerkleTree {
            leaves: array![].span(), digests: array![].span(), cap: MerkleCapsImpl::default(),
        }
    }

    fn new(leaves: Array<Goldilocks>, cap_size: usize) -> MerkleTree {
        let num_leaves = leaves.len();
        let mut digests: Array<Goldilocks> = array![];

        // Populate the leaves and compute hashes for internal nodes
        let mut i = 0;

        let l = leaves.clone();

        // Compute the first level of internal nodes
        while i < num_leaves {
            let hash_val = hash_n_to_m_no_pad(
                array![*l[i], *l[i + 1]].span(), 1
            )[0]; // 2 to one hash
            digests.append(*hash_val);
            i += 2;
        };

        // Compute subsequent levels
        let mut level_size = num_leaves / 2;
        let mut start_idx = 0;

        while level_size
            / 2 > cap_size {
                i = 0;
                while i < level_size {
                    let hash_val = hash_n_to_m_no_pad(
                        array![*digests[start_idx + i], *digests[start_idx + i + 1]].span(), 1
                    )[0];
                    digests.append(*hash_val);
                    i += 2;
                    println!("added {}", level_size);
                };
                start_idx += level_size;
                level_size /= 2;
            };

        let mut cap: Array<Goldilocks> = array![];
        let d = digests.clone();

        let mut i = start_idx;
        while cap
            .len() < cap_size {
                let hash_val = hash_n_to_m_no_pad(array![*d[i], *d[i + 1]].span(), 1)[0];
                cap.append(*hash_val);
                i += 2;
            };

        MerkleTree { leaves: leaves.span(), digests: digests.span(), cap: MerkleCaps { data: cap } }
    }
}

fn log2_strict(x: usize) -> usize {
    let mut y = 0;
    let mut z = x;
    while z > 1 {
        z = z / 2;
        y = y + 1;
    };
    y
}

#[cfg(test)]
mod tests {
    use super::{gl, MerkleTreeImpl};

    #[test]
    fn test_init() {
        let leaves = array![gl(1), gl(2), gl(3), gl(4), gl(5), gl(6), gl(7), gl(8)];
        let cap_size = 2;
        let tree = MerkleTreeImpl::new(leaves, cap_size);
        assert_eq!(tree.leaves.len(), 8);
    }
}
