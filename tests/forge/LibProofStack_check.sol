// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
// import {vm} from "forge-std/Vm.sol";

import {LibProofStack, StackProof, ProofLeaf} from "chaintrap/libproofstack.sol";

import {LibProofStackFacade} from "tests/LibProofStack_Facade.sol";

contract LibProofStack_check is 
    Test {
    LibProofStackFacade f;

    constructor() {
        f = new LibProofStackFacade();
    }
    function test_check() public {
/*
        ProofStack memory stack = ProofStack(1);
        ProofState memory state = ProofState(false, 0);
        bool result = f.check(stack, state);
        assertTrue(result);
        */
    }
}
