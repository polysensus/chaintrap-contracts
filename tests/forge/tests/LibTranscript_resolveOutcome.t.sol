// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {TokenID} from "lib/tokenid.sol";
import {LibTranscript, TranscriptCommitment, TranscriptOutcome, TranscriptStartArgs} from "lib/libtranscript.sol";

import {Transcript_OutcomePending, Transcript_InvalidRootLabel, Transcript_NotRegistered} from "lib/libtranscript.sol";
import {Transcript_InvalidEntry} from "lib/libtranscript.sol";
import {Transcript_OutcomeVerifyFailed, Transcript_InvalidChoice} from "lib/libtranscript.sol";

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

        f.register(participant, "participant");

        f.start(proofID1StartArgs());

        // first, ensure there is a valid tid in place for participant address(1)
        f.entryCommit(participant, TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        // now resolve with valid argument
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.TranscriptEntryOutcome(
            gid, participant, 1, advocate, keccak256("Chaintrap:MapLinks"),
            LibTranscript.Outcome.Accepted, kp.node, hex"dbdb");
        f.entryResolve(
            advocate,
            TranscriptOutcome(
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

        f.register(participant, "participant");

        TranscriptStartArgs memory startArgs = proofID1StartArgs();

        f.start(startArgs);

        // first, ensure there is a valid tid in place for participant address(1)
        f.entryCommit(participant, TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        // now attempt to resolve for the randomWallet
        vm.expectRevert(Transcript_NotRegistered.selector);
        f.entryResolve(
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

        f.register(participant, "participant");

        TranscriptStartArgs memory startArgs = proofID1StartArgs();
        f.start(startArgs);

        // first, ensure there is a valid tid in place for participant address(1)
        f.entryCommit(participant, TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        f.forceTranscriptEntryOutcome(1, LibTranscript.Outcome.Invalid);

        // now attempt to resolve for the randomWallet
        vm.expectRevert(Transcript_InvalidEntry.selector);
        f.entryResolve(
            advocate, proofID1CommitArgument(participant, LibTranscript.Outcome.Accepted)); 
    }

    function test_revert_resolveOutcome_invalid_choice() public {
        f.pushTranscript();

        address participant = address(1);
        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.register(participant, "participant");

        TranscriptStartArgs memory startArgs = proofID1StartArgs();
        // default start args use kp.node as the only valid choice
        f.start(startArgs);

        vm.expectRevert(Transcript_InvalidChoice.selector);
        f.entryCommit(participant, TranscriptCommitment(keccak256("Chaintrap:MapLinks"), keccak256("node"), hex"03"));
    }

    function test_revert_resolveOutcome_invalid_proof() public {
        f.pushTranscript();

        address participant = address(1);
        address advocate = address(20);
        KnownProof storage kp = knownProofs[ProofID1];

        uint256 gid = TokenID.GAME2_TYPE | 1;
        f._init(gid, address(1), initArgsWith1Root(keccak256("Chaintrap:MapLinks"), kp.root));

        f.register(participant, "participant");

        TranscriptStartArgs memory startArgs = proofID1StartArgs();
        // default start args use kp.node as the only valid choice
        f.start(startArgs);

        f.entryCommit(participant, TranscriptCommitment(keccak256("Chaintrap:MapLinks"), kp.node, hex"03"));

        TranscriptOutcome memory argument = proofID1CommitArgument(participant, LibTranscript.Outcome.Accepted);
        argument.proof[1] = hex"840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f6";
        vm.expectRevert(Transcript_OutcomeVerifyFailed.selector);
        f.entryResolve( advocate, argument);
    }
}
