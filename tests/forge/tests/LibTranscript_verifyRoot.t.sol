// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {GameIsInitialised, InvalidProof} from "lib/libtranscript2.sol";
import {LibTranscript, Transcript2, TranscriptInitArgs} from "lib/libtranscript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils } from "tests/TranscriptUtils.sol";

contract LibGame_verifyRoot is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {
    using LibTranscript  for Transcript2;
    using stdStorage for StdStorage;

    function test_verifyRoot() public {

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
        bytes32 leaf = hex"89b28fc7a697b39897740df65cec519eaf9c56ce8f5a88d04e8bc976a91703e9";
        bytes32 root = hex"141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562";
        bytes32[] memory proof = new bytes32[](5);
        proof[0] = hex"840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f7";
        proof[1] = hex"c6abef3208a3433ad2e81daeee8d77789e2abc6ccb45db41fcf2e85c14ed2834";
        proof[2] = hex"98541c3fd2ce651a452bb8f0d4812fa4ac0231c9d1c0eb7d7353949da4289725";
        proof[3] = hex"54149a09f84ed0d33400271f1c66d5bac2299cd6c5695194c77c1d6165f51fbe";
        proof[4] = hex"8c4e03aa1a345609a3550b6a1d33de710ecd0398f38c992344b78b0b4aaf4ff7";

        f.pushTranscript();
        bytes32[] memory rootLabels = new bytes32[](1);
        bytes32[] memory roots = new bytes32[](1);
        rootLabels[0]=hex"aaaa";
        roots[0] = root;
        f._init(1, TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels:rootLabels,
            roots:roots}
            ));

        f.verifyRoot(proof, hex"aaaa", leaf);

        // check we revert for proof failed due to bad label
        vm.expectRevert(InvalidProof.selector);
        f.verifyRoot(proof, hex"bbbb", leaf);
    }
}