// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import "lib/interfaces/ITranscript2Errors.sol";

import {LibTranscript, ActionCommitment} from "lib/libtranscript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils } from "tests/TranscriptUtils.sol";

contract LibGame_commitAction is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {

    /**@dev test that an unregistered participant is handled correctly
     */
    function test_revertIfParticipantUnregistered() public {
        f.pushTranscript();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

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
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        f.registerParticipant(address(1), "player one");
        f.registerParticipant(address(2), "player two");

        // force the game into started state
        f.forceGameState(LibTranscript.GameState.Started);

        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ActionCommitted(gid, 1, address(1), keccak256("Chaintrap:MapLinks"), hex"03");
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));

        vm.expectRevert(OutcomePending.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"05"));

        // But it is fine for a different participant (note the tid advances)
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ActionCommitted(gid, 2, address(2), keccak256("Chaintrap:MapLinks"), hex"05");
        f.commitAction(address(2), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"05"));
    }

    function test_revertIfRootLabelBad() public {
        f.pushTranscript();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibTranscript.GameState.Started);

        vm.expectRevert(InvalidRootLabel.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Gibberish"), keccak256("node"), hex"03"));
    }
}
