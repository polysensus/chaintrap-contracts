// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import {LibGame, ActionCommitment, OutcomePending, InvalidRootLabel} from "lib/transcript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils } from "tests/TranscriptUtils.sol";

contract LibGame_commitAction is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {

    /**@dev test that an unregistered participant is handled correctly
     */
    function test_commitAction_unregistered_participant() public {
        f.pushGame();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        vm.expectEmit(true, true, true, true);
        emit LibGame.ActionCommitted(gid, 1, address(1), keccak256("Chaintrap:MapLinks"), hex"03");
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));
    }

    /** @dev test we get a revert if an attempt is made to commit a new action
     * when one is already pending for the participant */
    function test_revert_commitAction_when_pending() public {
        f.pushGame();

        // initialise the game
        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        vm.expectEmit(true, true, true, true);
        emit LibGame.ActionCommitted(gid, 1, address(1), keccak256("Chaintrap:MapLinks"), hex"03");
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));

        vm.expectRevert(OutcomePending.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"05"));

        // But it is fine for a different participant (note the tid advances)
        vm.expectEmit(true, true, true, true);
        emit LibGame.ActionCommitted(gid, 2, address(2), keccak256("Chaintrap:MapLinks"), hex"05");
        f.commitAction(address(2), ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"05"));
    }

    function test_revert_commitAction_bad_root_label() public {
        f.pushGame();

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        vm.expectRevert(InvalidRootLabel.selector);
        f.commitAction(address(1), ActionCommitment(keccak256("Gibberish"), keccak256("node"), hex"03"));
    }
}
