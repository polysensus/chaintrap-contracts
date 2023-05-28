// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import "lib/interfaces/ITranscript2Errors.sol";

import {LibTranscript, ActionCommitment, StartGameArgs} from "lib/libtranscript2.sol";

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
        f.forceGameState(LibTranscript.GameState.Started);

        vm.expectRevert(NotRegistered.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));
    }

    /** @dev test we get a revert if an attempt is made to commit a new action
     * when one is already pending for the participant */
    function test_revertOnCommitIfActionIsPending() public {
        f.pushTranscript();

        // initialise the game
        uint256 gid = TokenID.GAME2_TYPE | 1;
        KnownProof storage kp = knownProofs[ProofID1];

        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(address(1), "player one");
        f.registerParticipant(address(2), "player two");

        StartGameArgs memory args = proofID1StartArgsNParticipants(2);
        f.startGame2(args);

        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ActionCommitted(gid, 1, address(1), keccak256("Chaintrap:MapLinks"), kp.node, hex"03");
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        vm.expectRevert(OutcomePending.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"05"));

        // But it is fine for a different participant (note the tid advances)
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ActionCommitted(gid, 2, address(2), keccak256("Chaintrap:MapLinks"), kp.node, hex"05");
        f.commitAction(address(2), ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"05"));
    }

    function test_revertIfRootLabelBad() public {
        f.pushTranscript();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibTranscript.GameState.Started);

        vm.expectRevert(InvalidRootLabel.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Gibberish"), keccak256("node"), hex"03"));
    }
}
