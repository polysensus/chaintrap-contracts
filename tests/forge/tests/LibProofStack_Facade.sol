
pragma solidity =0.8.9;

import {LibProofStack, StackProof, ProofLeaf } from "lib/libproofstack.sol";

contract LibProofStackFacade {
    mapping(bytes32 => bytes32) roots;

    function init(
        bytes32[] calldata _rootLabels,
        bytes32[] calldata _roots
    ) public {
        for (uint i=0; i<_rootLabels.length; i++)
            roots[_rootLabels[i]] = _roots[i];
    }

    function check(
        StackProof[] calldata stack,
        ProofLeaf[] calldata leaves
        ) public view returns (bytes32[] memory, bool) {
        return LibProofStack.check(stack, leaves, roots);
    }
}