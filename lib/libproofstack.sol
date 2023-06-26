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

struct ChoiceProof {
    uint256 choiceSetType;
    uint256 transitionType;
    StackProof[] stack;
    ProofLeaf[] leaves;
}

struct StackState {
    uint256 i;
    bytes32[] proven;
    uint256 refFloor;
    uint256 nextProofRef;
    uint256 nextInputRef;
    uint256 floorBreached;
}

library LibProofStack {
    /// @dev compute the leaf pre-image assuming that the inputs are the actual
    /// values rather than references.
    function directPreimage(
        ProofLeaf calldata leaf
    ) internal pure returns (bytes memory) {
        return abi.encode(leaf.typeId, leaf.inputs);
    }

    function directPreimage(
        ProofLeaf storage leaf
    ) internal view returns (bytes memory) {
        return abi.encode(leaf.typeId, leaf.inputs);
    }

    function directMerkleLeaf(
        ProofLeaf calldata leaf
    ) internal pure returns (bytes32) {
        return
            keccak256(
                bytes.concat(keccak256(LibProofStack.directPreimage(leaf)))
            );
    }

    function directMerkleLeaf(
        ProofLeaf storage leaf
    ) internal view returns (bytes32) {
        return
            keccak256(
                bytes.concat(keccak256(LibProofStack.directPreimage(leaf)))
            );
    }

    function check(
        ChoiceProof calldata args,
        mapping(bytes32 => bytes32) storage roots
    ) internal view returns (bytes32[] memory, bool) {
        bytes32[] memory proven = new bytes32[](args.stack.length);

        if (args.leaves[0].typeId != args.choiceSetType)
            revert ProofStack_MustStartWithChoiceSet();

        if (args.leaves[args.leaves.length - 1].typeId != args.transitionType)
            revert ProofStack_MustConcludeWithTransition();

        uint256 lastChoiceSet = 0;

        for (uint i = 0; i < args.stack.length; i++) {
            if (i > 0) {
                if (args.leaves[i].typeId != args.choiceSetType) {
                    // require that it has a back ref to ensure all entries
                    // derived from a choice set form a logical chain through
                    // the merkle tree.
                    if (
                        args.stack[i].inputRefs.length == 0 &&
                        args.stack[i].proofRefs.length == 0
                    ) revert ProofStack_MustBeDerivedFromChoiceSet();

                    // note we check that the references are for the most recent
                    // choice set  when resolving the indirection
                } else {
                    // Note: generalising this so we can have transitions
                    // contingent on choice combinations is a possible future
                    // direction. For now two is enough to emulate the
                    // roll-your-own-adventure model of page location chioces we
                    // are supporting.
                    if (lastChoiceSet != 0)
                        revert ProofStack_TooManyChoiceSets();
                    lastChoiceSet = i;
                }
            }

            bytes32 merkleLeaf = LibProofStack.entryLeafNode(
                args,
                StackState(i, proven, lastChoiceSet, 0, 0, 0)
            );

            /*
            console.log("merkleLeaf");
            console.logBytes32(merkleLeaf);
            console.log("rootLabel");
            console.logBytes32(stack[i].rootLabel);
            console.log("root");
            console.logBytes32(roots[stack[i].rootLabel]);
            */

            if (
                !MerkleProof.verifyCalldata(
                    args.stack[i].proof,
                    roots[args.stack[i].rootLabel],
                    merkleLeaf
                )
            ) return (proven, false);
            console.log("proven %d", i);

            proven[i] = merkleLeaf;
        }
        return (proven, true);
    }

    function entryLeafNode(
        ChoiceProof calldata args,
        StackState memory state
    ) internal view returns (bytes32) {
        if (
            args.stack[state.i].inputRefs.length == 0 &&
            args.stack[state.i].proofRefs.length == 0
        ) return LibProofStack.directMerkleLeaf(args.leaves[state.i]);
        else return LibProofStack.entryIndirectLeafNode(args, state);
    }

    function entryIndirectLeafNode(
        ChoiceProof calldata args,
        StackState memory state
    ) internal view returns (bytes32) {
        StackProof calldata item = args.stack[state.i];
        ProofLeaf calldata leaf = args.leaves[state.i];

        if (state.i == args.stack.length - 1) {
            // The last entry is the transition, it must have references to both
            // choice sets. could generalise this for multiple choice sets and
            // 'and' transitions in future.
            if (leaf.inputs.length != 2)
                revert ProofStack_TransitionProofIncomplete();
        }

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

            // is the next reference the input currently being collected ?
            if (
                state.nextProofRef < item.proofRefs.length &&
                item.proofRefs[state.nextProofRef] == j
            ) {
                console.log("PROOF REF ---");
                if (leaf.inputs[j].length != 1)
                    revert ProofStack_ProoRefInvalid();

                bytes32 value = leaf.inputs[j][leaf.inputs[j].length - 1];

                if (uint256(value) < state.refFloor)
                    if (
                        state.i != args.stack.length - 1 ||
                        state.floorBreached != 0
                    )
                        // The transition references must span the floor, two below the floor or two above are both invalid.
                        revert ProofStack_ReferenceFloorBreach();
                    else state.floorBreached++;

                // It is a back reference to a node proven by a lower stack item.
                console.log("value");
                console.logBytes32(value);

                inputs[j][0] = state.proven[uint256(value)];
                console.log("pref: inputs 0");
                console.logBytes32(inputs[j][0]);

                state.nextProofRef++;
            } else if (
                state.nextInputRef < item.inputRefs.length &&
                item.inputRefs[state.nextInputRef] == j
            ) {
                console.log("INPUT REF ---");
                // Note: the value refered to here cannot be a reference. (or if it is it is not resolved to the target value)

                // It is an input ref there must be *at least* two values, the stack position and the input index.

                if (leaf.inputs[j].length < 2)
                    revert ProofStack_InputRefToShort();

                uint stackPos = uint(leaf.inputs[j][leaf.inputs[j].length - 2]);
                if (stackPos < state.refFloor)
                    if (
                        state.i != args.stack.length - 1 ||
                        state.floorBreached != 0
                    )
                        // The transition references must span the floor, two below the floor or two above are both invalid.
                        revert ProofStack_ReferenceFloorBreach();
                    else state.floorBreached++;

                bytes32[] calldata referedInput = args.leaves[stackPos].inputs[
                    uint(leaf.inputs[j][leaf.inputs[j].length - 1])
                ];

                // allocate space for target leaf hash + refered inputs
                inputs[j] = new bytes32[](referedInput.length + 1);

                inputs[j][0] = state.proven[stackPos];
                console.log("iref: target hash");
                console.logBytes32(inputs[j][0]);

                for (uint k = 0; k < referedInput.length; k++) {
                    inputs[j][k + 1] = referedInput[k];
                    console.log("iref: inputs %d", k + 1);
                    console.logBytes32(inputs[j][k + 1]);
                }
                state.nextInputRef++;
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

        if (state.i == args.stack.length - 1 && state.floorBreached != 1)
            revert ProofStack_MustDeriveFromBothChoiceSet();

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
