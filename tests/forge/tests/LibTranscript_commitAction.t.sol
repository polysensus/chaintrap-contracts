// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import "lib/interfaces/ITranscriptErrors.sol";

import {LibTranscript, TranscriptCommitment, TranscriptStartArgs} from "lib/libtranscript.sol";

import {
    TranscriptWithFactory,
    TranscriptInitUtils,
    Transcript2KnowProofUtils, KnownProof
    } from "tests/TranscriptUtils.sol";

contract LibGame_commitAction is
    TranscriptWithFactory,
    TranscriptInitUtils,
    Transcript2KnowProofUtils,
    DSTest {

    /**@dev test that an unregistered participant is handled correctly
     */
    function test_revertIfParticipantUnregistered() public {
        f.pushTranscript();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibTranscript.State.Started);

        vm.expectRevert(Transcript_NotRegistered.selector);
        f.entryCommit(address(1), TranscriptCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));
    }

    /** @dev test we get a revert if an attempt is made to commit a new action
     * when one is already pending for the participant */
    function test_revertOnCommitIfActionIsPending() public {
        f.pushTranscript();

        // initialise the game
        uint256 gid = TokenID.GAME2_TYPE | 1;
        KnownProof storage kp = knownProofs[ProofID1];

        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.register(address(1), "player one");
        f.register(address(2), "player two");

        TranscriptStartArgs memory args = proofID1StartArgsNParticipants(2);
        f.start(args);

        vm.expectEmit(true, true, true, true);
        emit LibTranscript.TranscriptEntryCommitted(gid, address(1), 1, keccak256("Chaintrap:MapLinks"), kp.node, hex"03");
        f.entryCommit(address(1), TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        vm.expectRevert(Transcript_OutcomePending.selector);
        f.entryCommit(address(1), TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"05"));

        // But it is fine for a different participant (note the tid advances)
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.TranscriptEntryCommitted(gid, address(2), 2, keccak256("Chaintrap:MapLinks"), kp.node, hex"05");
        f.entryCommit(address(2), TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"05"));
    }

    function test_revertIfRootLabelBad() public {
        f.pushTranscript();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibTranscript.State.Started);

        vm.expectRevert(Transcript_InvalidRootLabel.selector);
        f.entryCommit(address(1), TranscriptCommitment(keccak256("Gibberish"), keccak256("node"), hex"03"));
    }
}
