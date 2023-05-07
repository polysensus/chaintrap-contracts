// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TranscriptInitArgs} from "lib/transcript2.sol";

import {HEVM_ADDRESS} from "tests/constants.sol";
import {TranscriptFactory} from "tests/TranscriptFactory.sol";

contract TranscriptWithFactory {
    using stdStorage for StdStorage;

    Vm vm = Vm(HEVM_ADDRESS);
    StdStorage stdstore;
    TranscriptFactory f;

    constructor() {
        f = new TranscriptFactory();
        f.pushGame(); // make zero'th inaccessible
    }
}

contract TranscriptInitUtils {
    function minimalyValidInitArgs() internal pure returns (TranscriptInitArgs memory) {
        return TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels:new bytes32[](1),
            roots:new bytes32[](1)}
            );
    }
    function initArgsWith1Root(bytes32 label, bytes32 root) internal pure returns (TranscriptInitArgs memory) {
        bytes32[] memory labels = new bytes32[](1);
        bytes32[] memory roots = new bytes32[](1);
        labels[0] = label;
        roots[0] = root;
        return TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels: labels,
            roots: roots}
            );
    }
}

/// @dev for test convenience we have a few well know proofs generated from chaintrap tooling
struct KnownProof {
    bytes32 root;
    bytes32[] proof;
    bytes32 node;
}

contract Game2KnowProofUtils {

    mapping(string=>KnownProof) knownProofs;

    constructor() {
        KnownProof storage kp = knownProofs["map02:[[8,3,0],[0,1,0]]"];

        // generated from map02.json using chaintrap-arenastate/cli.js
        //   maptrieproof tests/data/maps/map02.json 1
        // {
        //      "value":[[8,3,0],[0,1,0]],
        //      "leaf":"0x89b28fc7a697b39897740df65cec519eaf9c56ce8f5a88d04e8bc976a91703e9",
        //      "root":"0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
        //      "proof":[
        //          "0x840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f7",
        //          "0xc6abef3208a3433ad2e81daeee8d77789e2abc6ccb45db41fcf2e85c14ed2834",
        //          "0x98541c3fd2ce651a452bb8f0d4812fa4ac0231c9d1c0eb7d7353949da4289725",
        //          "0x54149a09f84ed0d33400271f1c66d5bac2299cd6c5695194c77c1d6165f51fbe",
        //          "0x8c4e03aa1a345609a3550b6a1d33de710ecd0398f38c992344b78b0b4aaf4ff7"
        //     ]
        //  }
        kp.node = hex"89b28fc7a697b39897740df65cec519eaf9c56ce8f5a88d04e8bc976a91703e9";
        kp.root = hex"141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562";
        kp.proof = new bytes32[](5);
        kp.proof[0] = hex"840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f7";
        kp.proof[1] = hex"c6abef3208a3433ad2e81daeee8d77789e2abc6ccb45db41fcf2e85c14ed2834";
        kp.proof[2] = hex"98541c3fd2ce651a452bb8f0d4812fa4ac0231c9d1c0eb7d7353949da4289725";
        kp.proof[3] = hex"54149a09f84ed0d33400271f1c66d5bac2299cd6c5695194c77c1d6165f51fbe";
        kp.proof[4] = hex"8c4e03aa1a345609a3550b6a1d33de710ecd0398f38c992344b78b0b4aaf4ff7";
    }
}