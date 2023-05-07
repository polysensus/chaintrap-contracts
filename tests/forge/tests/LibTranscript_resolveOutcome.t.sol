// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import {LibGame, ActionCommitment, OutcomeArgument} from "lib/transcript2.sol";

import {OutcomePending, InvalidRootLabel, InvalidParticipant} from "lib/transcript2.sol";
import {InvalidTranscriptEntry} from "lib/transcript2.sol";
import {ArgumentInvalidAcceptedMustBeProofOfInclusion} from "lib/transcript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils, Game2KnowProofUtils } from "tests/TranscriptUtils.sol";
import {Game2KnowProofUtils, KnownProof } from "tests/TranscriptUtils.sol";

contract LibGame_resolveOutcome is
    TranscriptWithFactory,
    TranscriptInitUtils,
    Game2KnowProofUtils,
    DSTest {

    function test_resolveOutcome() public {
        f.pushGame();

        KnownProof storage kp = knownProofs["map02:[[8,3,0],[0,1,0]]"];

        address participant = address(1);
        address advocate = address(20);

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        // now resolve with valid argument
        vm.expectEmit(true, true, true, true);
        emit LibGame.ArgumentProven(gid, 1, advocate);
        emit LibGame.OutcomeResolved(gid, 1, participant, advocate, keccak256("Chaintrap:MapLinks"), LibGame.Outcome.Accepted, hex"dbdb");
        f.resolveOutcome(
            advocate,
            OutcomeArgument(
                participant, LibGame.Outcome.Accepted,
                hex"dbdb", kp.proof, kp.node) 
        );
    }


    function test_revert_resolveOutcome_invalid_tid() public {
        f.pushGame();

        address participant = address(1);
        address advocate = address(20);
        address randomWallet = address(999);

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));

        // now attempt to resolve for the randomWallet
        vm.expectRevert(InvalidParticipant.selector);
        f.resolveOutcome(
            advocate,
            OutcomeArgument(
                randomWallet, LibGame.Outcome.Accepted,
                hex"dbdb", new bytes32[](1),keccak256("node")) 
        );
    }

    function test_revert_resolveOutcome_invalid_current_outcome() public {
        f.pushGame();

        address participant = address(1);
        address advocate = address(20);

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));

        f.forceTranscriptEntryOutcome(1, LibGame.Outcome.Invalid);

        // now attempt to resolve for the randomWallet
        vm.expectRevert(InvalidTranscriptEntry.selector);
        f.resolveOutcome(
            advocate,
            OutcomeArgument(
                participant, LibGame.Outcome.Accepted,
                hex"dbdb", new bytes32[](1),keccak256("node")) 
        );
    }

    function test_revert_resolveOutcome_invalid_current_node() public {
        f.pushGame();

        address participant = address(1);
        address advocate = address(20);

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, initArgsWith1Root(keccak256("Chaintrap:MapLinks"), keccak256("")));

        // force the game into started state
        f.forceGameState(LibGame.GameState.Started);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));

        // now attempt to resolve for the randomWallet
        vm.expectRevert(ArgumentInvalidAcceptedMustBeProofOfInclusion.selector);
        f.resolveOutcome(
            advocate,
            OutcomeArgument(
                participant, LibGame.Outcome.Accepted,
                hex"dbdb", new bytes32[](1),keccak256("wrong-node")) 
        );
    }
}
