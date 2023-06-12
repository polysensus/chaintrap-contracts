// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

struct ProofLeaf {
    uint256 typeId;
    /// @dev for regular inputs, each item is a single element array.  For
    /// choice menu inputs, each item is a *pair* [path, value]. Eg,
    ///
    ///     regular inputs: [[value], [value], [value], ...]
    ///     choice menu: [[path, value], [path, value], ...]
    ///
    /// For the choice menu, the path encodes the depth first linearisation of a
    /// choice menu structure. It is suggested applications partion the path
    /// value evenly according to an application defined max menu depth. Eg, for
    /// a menu depth of 2, path should be a pair of packed bytes128's.
    ///  In both cases the 'value' portion of the input can be direct or it can
    /// be a reference. See StackProof for the details.
    bytes32[][] inputs;
}

/// @dev A StackProof is a proof where the proven node may be constructed from
/// elements of earlier proofs in the same stack.
struct StackProof {
    /// @dev inputRefs are used to construct proofs linking 'choice' inputs from
    /// earlier StackProofs to their pre-committed consequences.  Each index in
    /// the array identifies an earler StackProof's. The value in the associated
    /// proof entry input indexes into the inputs of the an earlier StackProof.
    uint256[] inputRefs;
    uint256[] proofRefs; // the value is read indirectly from the proven result identified by the value
    bytes32 rootLabel; // label
    bytes32[] proof;
}

library LibProofStack {
    /// @dev compute the leaf pre-image assuming that the inputs are the actual
    /// values rather than references.
    function directPreimage(
        ProofLeaf calldata leaf
    ) internal pure returns (bytes memory) {
        bytes memory leafPreimage = bytes.concat();
        for (uint i = 0; i < leaf.inputs.length; i++) {
            bytes32[] calldata input = leaf.inputs[i];
            bytes32 value = input[input.length - 1];

            /// Is it a menu choice value ?
            if (input.length == 2) {
                // If it's a choice leaf then there is a path to include If one
                // entry has length 2, they all should have, but at this level
                // we don't care.
                bytes32 path = input[0];
                value = keccak256(abi.encode(path, value));
            }
            leafPreimage = bytes.concat(leafPreimage, value);
        }
        return leafPreimage;
    }

    function directMerkleLeaf(
        ProofLeaf calldata leaf
    ) internal pure returns (bytes32) {
        bytes memory leafPreimage = LibProofStack.directPreimage(leaf);
        return keccak256(bytes.concat(keccak256(leafPreimage)));
    }

    function check(
        StackProof[] calldata stack,
        ProofLeaf[] calldata leaves,
        mapping(bytes32 => bytes32) storage roots
    ) internal view returns (bytes32[] memory, bool) {
        bytes32[] memory proven = new bytes32[](stack.length);

        for (uint i = 0; i < stack.length; i++) {
            bytes32 merkleLeaf = LibProofStack.entryLeafNode(
                    stack,
                    leaves,
                    i,
                    proven
                );
            if (
                !MerkleProof.verifyCalldata(
                    stack[i].proof,
                    roots[stack[i].rootLabel],
                    merkleLeaf
                )
            ) return (proven, false);

            proven[i] = merkleLeaf;
        }
        return (proven, true);
    }

    function entryLeafNode(
        StackProof[] calldata stack,
        ProofLeaf[] calldata leaves,
        uint256 i,
        bytes32[] memory proven
    ) internal pure returns (bytes32) {
        StackProof calldata item = stack[i];
        ProofLeaf calldata leaf = leaves[i];
        bytes memory leafPreimage = bytes.concat();
        uint nextProofRef = 0;
        uint nextInputRef = 0;
        for (uint j = 0; j < leaf.inputs.length; j++) {
            // The value is always the last element of the specific input. For
            // reference inputs, the immediave value is used to look up the
            // refered value.
            bytes32 value = leaf.inputs[j][leaf.inputs[j].length - 1];

            // is the next reference the input currently being collected ?
            if (
                nextProofRef < item.proofRefs.length &&
                item.proofRefs[nextProofRef] == j
            ) {
                // It is a back reference to a node proven by a lower stack item.
                value = proven[uint256(value)];
                nextProofRef++;
            } else if (
                nextInputRef < item.inputRefs.length &&
                item.inputRefs[nextInputRef] == j
            ) {
                // Note: the value refered to here cannot be a reference. (or if it is it is not resolved to the target value)

                // value indexes the input holding the actual value
                bytes32[] calldata input = leaves[(uint256(value) >> 128)].inputs[
                    uint128(uint256(value) & 0xffffffffffffffffffffffffffffffff)
                ];
                value = input[input.length - 1];
                if (input.length == 2) {
                    // If it's a choice leaf then there is a path to include
                    bytes32 path = input[0];
                    value = keccak256(abi.encode(path, value));
                }
                nextInputRef++;
            }
            // else the value is not a reference and it needs no further
            // resolution.

            // Note: Because we are always catenating fixed 32 byte chunks. and
            // because the final payload is perfixed with an ordinal type
            // discriminator there is no possiblity of crafting hash collisions.
            leafPreimage = bytes.concat(leafPreimage, value);
        }
        return keccak256(bytes.concat(keccak256(bytes.concat(abi.encode(leaf.typeId, leafPreimage)))));
    }
}
