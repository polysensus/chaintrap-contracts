// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "hardhat/console.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "chaintrap/interfaces/IProofStackErrors.sol";

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
    uint256 position; // program counter sort of
    bytes32[] proven;
    // @dev refFloor is lastChoiceSet
    uint256 lastChoiceSet;
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
    ) internal view returns (StackState memory, bool) {
        StackState memory state = StackState(
            0,
            new bytes32[](args.stack.length),
            0,
            0
        );

        if (args.leaves[0].typeId != args.choiceSetType)
            revert ProofStack_MustStartWithChoiceSet();

        if (args.leaves[args.leaves.length - 1].typeId != args.transitionType)
            revert ProofStack_MustConcludeWithTransition();

        for (uint i = 0; i < args.stack.length; i++) {
            state.position = i;

            if (i > 0) {
                if (args.leaves[i].typeId != args.choiceSetType) {
                    // require that it has a back ref to ensure all entries
                    // derived from a choice set form a logical chain through
                    // the merkle tree.
                    if (
                        args.stack[i].inputRefs.length == 0 &&
                        args.stack[i].proofRefs.length == 0
                    ) revert ProofStack_MustBeDerivedFromChoiceSet();
                    // TODO: consider making the revers returns and letting the caller revert or not.
                    // state.position + error code is enough info

                    // note we check that the references are for the most recent
                    // choice set  when resolving the indirection
                } else {
                    // Note: generalising this so we can have transitions
                    // contingent on choice combinations (choice a AND choice b
                    // THEN choice set c) is a possible future direction. For
                    // now choice a -> choice set new is enought for the
                    // roll-your-own-adventure model of page location chioces we
                    // are supporting.
                    if (state.lastChoiceSet != 0)
                        revert ProofStack_TooManyChoiceSets();
                    state.lastChoiceSet = i;
                }
            }

            bytes32 merkleLeaf = LibProofStack.entryLeafNode(args, state, i);
            console.log("merkleLeaf & proof[0]:");
            console.logBytes32(merkleLeaf);
            console.logBytes32(args.stack[i].proof[0]);

            if (
                !MerkleProof.verifyCalldata(
                    args.stack[i].proof,
                    roots[args.stack[i].rootLabel],
                    merkleLeaf
                )
            ) return (state, false);

            // if we have more than one choice set, require that the proof for
            // the most recent refers to leaves associated with the earlier
            // choice set (below the floor). Note: this clause alows for > 2
            // choice sets for now.
            if (
                i == args.stack.length - 1 &&
                state.lastChoiceSet > 1 &&
                state.floorBreached != 1
            ) revert ProofStack_MustDeriveFromBothChoiceSet();

            console.log("proven %d", i);

            state.proven[i] = merkleLeaf;
        }
        return (state, true);
    }

    function entryLeafNode(
        ChoiceProof calldata args,
        StackState memory state,
        uint256 i
    ) internal view returns (bytes32) {
        if (
            args.stack[i].inputRefs.length == 0 &&
            args.stack[i].proofRefs.length == 0
        ) return LibProofStack.directMerkleLeaf(args.leaves[i]);
        else return LibProofStack.entryIndirectLeafNode(args, state, i);
    }

    function entryIndirectLeafNode(
        ChoiceProof calldata args,
        StackState memory state,
        uint256 i
    ) internal view returns (bytes32) {
        StackProof calldata item = args.stack[i];
        ProofLeaf calldata leaf = args.leaves[i];

        uint256 nextProofRef = 0;
        uint256 nextInputRef = 0;

        // Note: memory expansion and copying from calldata could probably be
        // avoided with clever encoding. But it shouldn't be that bad for now.
        // https://ethereum.stackexchange.com/questions/92546/what-is-expansion-cost

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
                nextProofRef < item.proofRefs.length &&
                item.proofRefs[nextProofRef] == j
            ) {
                console.log("STACK(%d)[%d] PROOF REF ---", i, j);
                if (leaf.inputs[j].length != 1)
                    revert ProofStack_ProoRefInvalid();

                bytes32 value = leaf.inputs[j][leaf.inputs[j].length - 1];

                if (uint256(value) < state.lastChoiceSet)
                    if (i != args.stack.length - 1 || state.floorBreached != 0)
                        // The transition references must span the floor, two below the floor or two above are both invalid.
                        revert ProofStack_ReferenceFloorBreach();
                    else state.floorBreached++;

                // It is a back reference to a node proven by a lower stack item.
                console.log("proof index %d", uint256(value));

                inputs[j][0] = state.proven[uint256(value)];
                console.log("proof value %s", uint256(inputs[j][0]));

                nextProofRef++;
            } else if (
                nextInputRef < item.inputRefs.length &&
                item.inputRefs[nextInputRef] == j
            ) {
                console.log("STACK(%d)[%d] INPUT REF ---", i, j);
                // Note: the value refered to here cannot be a reference. (or if it is it is not resolved to the target value)

                // It is an input ref there must be *at least* two values, the stack position and the input index.

                if (leaf.inputs[j].length < 2)
                    revert ProofStack_InputRefToShort();

                // index back from the end of the input so we can have other values *before* the stack position
                uint stackPos = uint(leaf.inputs[j][leaf.inputs[j].length - 2]);
                if (stackPos < state.lastChoiceSet)
                    if (i != args.stack.length - 1 || state.floorBreached != 0)
                        // Each choice set establishes a 'floor'. Transition
                        // references, which result in a new choice set, must
                        // span the floor in order to demonstrate a connection between
                        // the twho choice sets.
                        revert ProofStack_ReferenceFloorBreach();
                    else state.floorBreached++;

                console.log("proof index %d", stackPos);

                // The input reference is the last input item, henge length - 1
                bytes32[] calldata referedInput = args.leaves[stackPos].inputs[
                    uint(leaf.inputs[j][leaf.inputs[j].length - 1])
                ];

                // allocate space for target leaf hash + refered inputs
                inputs[j] = new bytes32[](referedInput.length + 1);

                inputs[j][0] = state.proven[stackPos];
                console.log("proof value");
                console.logBytes32(inputs[j][0]);

                for (uint k = 0; k < referedInput.length; k++) {
                    inputs[j][k + 1] = referedInput[k];
                    console.log("iref: inputs %d", k + 1);
                    console.log(
                        "proof input: %d, %d",
                        k + 1,
                        uint256(inputs[j][k + 1])
                    );
                    console.logBytes32(referedInput[k]);
                }
                nextInputRef++;
            } else {
                console.log("STACK (%d)[%d] DIRECT PROOF ---", i, j);
                for (uint k = 0; k < leaf.inputs[j].length; k++) {
                    inputs[j][k] = leaf.inputs[j][k];
                    console.log(
                        "noref: inputs %d, %d",
                        k,
                        uint256(inputs[j][k])
                    );
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
