// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "hardhat/console.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "lib/interfaces/IProofStackErrors.sol";

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
        return abi.encode(leaf.typeId, leaf.inputs);
    }

    function directMerkleLeaf(
        ProofLeaf calldata leaf /*pure console.log */
    ) internal pure returns (bytes32) {
        return
            keccak256(
                bytes.concat(keccak256(LibProofStack.directPreimage(leaf)))
            );
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
            console.log("merkleLeaf");
            console.logBytes32(merkleLeaf);
            console.log("rootLabel");
            console.logBytes32(stack[i].rootLabel);
            console.log("root");
            console.logBytes32(roots[stack[i].rootLabel]);

            if (
                !MerkleProof.verifyCalldata(
                    stack[i].proof,
                    roots[stack[i].rootLabel],
                    merkleLeaf
                )
            ) return (proven, false);
            console.log("proven %d", i);

            proven[i] = merkleLeaf;
        }
        return (proven, true);
    }

    function entryLeafNode(
        StackProof[] calldata stack,
        ProofLeaf[] calldata leaves,
        uint256 i,
        bytes32[] memory proven /*pure console.log */
    ) internal view returns (bytes32) {
        if (stack[i].inputRefs.length == 0 && stack[i].proofRefs.length == 0)
            return LibProofStack.directMerkleLeaf(leaves[i]);
        else
            return
                LibProofStack.entryIndirectLeafNode(stack, leaves, i, proven);
    }

    function entryIndirectLeafNode(
        StackProof[] calldata stack,
        ProofLeaf[] calldata leaves,
        uint256 i,
        bytes32[] memory proven /*pure console.log */
    ) internal view returns (bytes32) {
        StackProof calldata item = stack[i];
        ProofLeaf calldata leaf = leaves[i];
        uint nextProofRef = 0;
        uint nextInputRef = 0;

        // Note: memory expansion and copying from calldata could probably be
        // avoided with clever encoding. But it shouldn't be that bad for now.
        // https://ethereum.stackexchange.com/questions/92546/what-is-expansion-cost

        // Remember, in solidity (at the point of allocation only) the 'outer'
        // dimension is on the right read as (bytes32[])[]  and length applies
        // to the outermost
        bytes32[][] memory inputs = new bytes32[][](leaf.inputs.length);

        for (uint j = 0; j < leaf.inputs.length; j++) {
            inputs[j] = new bytes32[](leaf.inputs[j].length);

            // The inputs are interpreted like this
            // imediate input is [value0, ..., valueN]
            // proofRef input is [elements, stack-position]
            // inputRef input is [elements, stack-position, input-index]
            //
            // There are loads of ways this can be optimised structuraly if we
            // need too.

            // Always need the last value, no matter if it is a referece or what
            // kind of reference.  For reference inputs, the immediate value(s)
            // are used to look up the refered value.
            bytes32 value = leaf.inputs[j][leaf.inputs[j].length - 1];

            console.log("input value");
            console.logBytes32(value);

            // is the next reference the input currently being collected ?
            if (
                nextProofRef < item.proofRefs.length &&
                item.proofRefs[nextProofRef] == j
            ) {
                console.log("PROOF REF ---");
                if (leaf.inputs[j].length != 1)
                    revert ProofStack_ProoRefInvalid();

                // It is a back reference to a node proven by a lower stack item.
                inputs[j][0] = proven[uint256(value)];
                console.log("pref: inputs 0");
                console.logBytes32(inputs[j][0]);

                nextProofRef++;
            } else if (
                nextInputRef < item.inputRefs.length &&
                item.inputRefs[nextInputRef] == j
            ) {
                console.log("INPUT REF ---");
                // Note: the value refered to here cannot be a reference. (or if it is it is not resolved to the target value)

                // It is an input ref there must be *at least* two values, the stack position and the input index.

                if (leaf.inputs[j].length < 2)
                    revert ProofStack_InputRefToShort();

                uint stackPos = uint(leaf.inputs[j][leaf.inputs[j].length - 2]);
                bytes32[] calldata referedInput = leaves[stackPos].inputs[
                    uint(value)
                ];
                inputs[j] = new bytes32[](referedInput.length);
                for (uint k = 0; k < referedInput.length; k++) {
                    inputs[j][k] = referedInput[k];
                    console.log("iref: inputs k");
                    console.logBytes32(inputs[j][k]);
                }
                nextInputRef++;
            } else {
                for (uint k = 0; k < leaf.inputs[j].length; k++) {
                    inputs[j][k] = leaf.inputs[j][k];
                    console.log("noref: inputs k");
                    console.logBytes32(inputs[j][k]);
                }
            }
            // else the value is not a reference and it needs no further
            // resolution.
        }
        bytes memory encoded = abi.encode(leaf.typeId, inputs);
        console.log("encoded");
        console.logBytes(encoded);
        return
            keccak256(
                bytes.concat(
                    keccak256(bytes.concat(abi.encode(leaf.typeId, inputs)))
                )
            );
    }
}
