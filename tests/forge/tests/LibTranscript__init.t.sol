// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {Transcript_IsInitialised, Transcript_VerifyFailed} from "lib/libtranscript.sol";
import {LibTranscript, Transcript, TranscriptInitArgs} from "lib/libtranscript.sol";

import {TranscriptWithFactory, TranscriptInitUtils, Transcript2KnowProofUtils } from "tests/TranscriptUtils.sol";

contract LibGame__init is
    TranscriptWithFactory,
    TranscriptInitUtils,
    Transcript2KnowProofUtils,
    DSTest {
    using LibTranscript  for Transcript;
    using stdStorage for StdStorage;

    function test_commitAction() public {
        f.pushTranscript();
    }

    function test__init_RevertInitialiseTwice() public {
        f.pushTranscript();
        f._init(1, address(1), minimalyValidInitArgs());

        vm.expectRevert(Transcript_IsInitialised.selector);
        f._init(1, address(1), minimalyValidInitArgs());
    }

    function test__init_RevertMoreRootsThanLabels() public {
        f.pushTranscript();

        vm.expectRevert(stdError.indexOOBError); // array out of bounds
        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            registrationLimit: 2,
            rootLabels:new bytes32[](1),
            roots:new bytes32[](2),
            choiceInputTypes: new uint256[](1),
            transitionTypes: new uint256[](2),
            victoryTransitionTypes: new uint256[](2),
            haltParticipantTransitionTypes: new uint256[](1)
            }
            ));
    }

    function test__init_NoRevertFewerRootsThanLabels() public {
        f.pushTranscript();

        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            registrationLimit: 1,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](1),
            choiceInputTypes: new uint256[](1),
            transitionTypes: new uint256[](2),
            victoryTransitionTypes: new uint256[](2),
            haltParticipantTransitionTypes: new uint256[](1)
            }
            ));
    }

    function test__init_EmitSetMerkleRoot() public {
        f.pushTranscript();

        vm.expectEmit(true, true, true, true);

        // Should get one emit for each root
        emit LibTranscript.TranscriptMerkleRootSet(1, "", "");
        emit LibTranscript.TranscriptMerkleRootSet(1, "", "");

        f._init(1, address(1), TranscriptInitArgs({
            tokenURI: "tokenURI",
            registrationLimit: 2,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](2),
            choiceInputTypes: new uint256[](1),
            transitionTypes: new uint256[](2),
            victoryTransitionTypes: new uint256[](2),
            haltParticipantTransitionTypes: new uint256[](1)
            }
            ));
    }
}