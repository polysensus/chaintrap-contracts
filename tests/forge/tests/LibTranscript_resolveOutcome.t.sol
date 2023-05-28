// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import {LibTranscript, ActionCommitment, OutcomeArgument, StartGameArgs} from "lib/libtranscript2.sol";

import {OutcomePending, InvalidRootLabel, InvalidParticipant} from "lib/libtranscript2.sol";
import {InvalidTranscript2Entry} from "lib/libtranscript2.sol";
import {ArgumentInvalidProofFailed, InvalidChoice} from "lib/libtranscript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils, Transcript2KnowProofUtils } from "tests/TranscriptUtils.sol";
import {Transcript2KnowProofUtils, KnownProof } from "tests/TranscriptUtils.sol";

contract LibTranscript_resolveOutcome is
    TranscriptWithFactory,
    TranscriptInitUtils,
    Transcript2KnowProofUtils,
    DSTest {

    function test_resolveOutcome() public {
        f.pushTranscript();

        KnownProof storage kp = knownProofs[ProofID1];

        address participant = address(1);
        address advocate = address(20);

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(participant, "participant");

        f.startGame2(proofID1StartArgs());

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        // now resolve with valid argument
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ArgumentProven(gid, 1, advocate);
        emit LibTranscript.OutcomeResolved(
            gid, 1, participant, advocate, keccak256("Chaintrap:MapLinks"),
            LibTranscript.Outcome.Accepted, kp.node, hex"dbdb");
        f.resolveOutcome(
            advocate,
            OutcomeArgument(
                participant, LibTranscript.Outcome.Accepted,
                hex"dbdb", kp.proof, new bytes32[](0)) 
        );
    }

    function test_revert_resolveOutcome_invalid_tid() public {
        f.pushTranscript();

        address participant = address(1);
        address advocate = address(20);
        address randomWallet = address(999);

        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(participant, "participant");

        StartGameArgs memory startArgs = proofID1StartArgs();

        f.startGame2(startArgs);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        // now attempt to resolve for the randomWallet
        vm.expectRevert(InvalidParticipant.selector);
        f.resolveOutcome(
            advocate,
            proofID1CommitArgument(randomWallet, LibTranscript.Outcome.Accepted)
        );
    }

    function test_revert_resolveOutcome_invalid_current_outcome() public {
        f.pushTranscript();

        address participant = address(1);
        address advocate = address(20);
        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(participant, "participant");

        StartGameArgs memory startArgs = proofID1StartArgs();
        f.startGame2(startArgs);

        // first, ensure there is a valid tid in place for participant address(1)
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        f.forceTranscriptEntryOutcome(1, LibTranscript.Outcome.Invalid);

        // now attempt to resolve for the randomWallet
        vm.expectRevert(InvalidTranscript2Entry.selector);
        f.resolveOutcome(
            advocate, proofID1CommitArgument(participant, LibTranscript.Outcome.Accepted)); 
    }

    function test_revert_resolveOutcome_invalid_choice() public {
        f.pushTranscript();

        address participant = address(1);
        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(participant, "participant");

        StartGameArgs memory startArgs = proofID1StartArgs();
        // default start args use kp.node as the only valid choice
        f.startGame2(startArgs);

        vm.expectRevert(InvalidChoice.selector);
        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));
    }

    function test_revert_resolveOutcome_invalid_proof() public {
        f.pushTranscript();

        address participant = address(1);
        address advocate = address(20);
        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.registerParticipant(participant, "participant");

        StartGameArgs memory startArgs = proofID1StartArgs();
        // default start args use kp.node as the only valid choice
        f.startGame2(startArgs);

        f.commitAction(participant, ActionCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        OutcomeArgument memory argument = proofID1CommitArgument(participant, LibTranscript.Outcome.Accepted);
        argument.proof[1] = hex"840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f6";
        vm.expectRevert(ArgumentInvalidProofFailed.selector);
        f.resolveOutcome( advocate, argument);
    }
}
