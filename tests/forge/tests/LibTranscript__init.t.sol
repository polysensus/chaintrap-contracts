// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {GameIsInitialised, InvalidProof} from "lib/libtranscript2.sol";
import {LibTranscript, Transcript2, TranscriptInitArgs} from "lib/libtranscript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils, Transcript2KnowProofUtils } from "tests/TranscriptUtils.sol";

contract LibGame__init is
    TranscriptWithFactory,
    TranscriptInitUtils,
    Transcript2KnowProofUtils,
    DSTest {
    using LibTranscript  for Transcript2;
    using stdStorage for StdStorage;

    function test_commitAction() public {
        f.pushTranscript();
    }

    function test__init_RevertInitialiseTwice() public {
        f.pushTranscript();
        f._init(1, address(1), minimalyValidInitArgs());

        vm.expectRevert(GameIsInitialised.selector);
        f._init(1, address(1), minimalyValidInitArgs());
    }

    function test__init_RevertMoreRootsThanLabels() public {
        f.pushTranscript();

        vm.expectRevert(stdError.indexOOBError); // array out of bounds
        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            maxParticipants: 2,
            rootLabels:new bytes32[](1),
            roots:new bytes32[](2)}
            ));
    }

    function test__init_NoRevertFewerRootsThanLabels() public {
        f.pushTranscript();

        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            maxParticipants: 1,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](1)}
            ));
    }

    function test__init_EmitSetMerkleRoot() public {
        f.pushTranscript();

        vm.expectEmit(true, true, true, true);

        // Should get one emit for each root
        emit LibTranscript.SetMerkleRoot(1, "", "");
        emit LibTranscript.SetMerkleRoot(1, "", "");

        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            maxParticipants: 2,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](2)}
            ));
    }
}