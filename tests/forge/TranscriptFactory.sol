// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Transcript_IsInitialised, Transcript_VerifyFailed} from "chaintrap/libtranscript.sol";
import {LibTranscript, TranscriptStartArgs} from "chaintrap/libtranscript.sol";
import {Transcript, TranscriptInitArgs} from "chaintrap/libtranscript.sol";
import {TranscriptCommitment, TranscriptOutcome} from "chaintrap/libtranscript.sol";

/*
 TranscriptFactory creates a new Transcript storage entry on demand and implements
 forwarders (to the most recently created) for all the LibTranscript methods that
 require calldata arguments
*/
contract TranscriptFactory {

    Transcript[] games;

    function pushTranscript() public {
        _pushGame();
    }

    function _pushGame() internal returns (Transcript storage) {
        uint256 i = games.length;
        games.push();
        return games[i];
    }


    function currentGame() internal view returns (Transcript storage) {
        return games[games.length - 1];
    }

    // --- helpers

    function forceGameState(LibTranscript.State state) public {
        currentGame().state = state;
    }

    function forceTranscriptEntryOutcome(uint256 tid, LibTranscript.Outcome outcome) public {
        currentGame().transcript[tid].outcome = outcome;
    }


    // --- LibTranscript public forwarders
    // These are required to make calldata work 
    function _init(uint256 id, address creator, TranscriptInitArgs calldata args) public {
        LibTranscript._init(currentGame(), id, creator, args);
    }
    function start(TranscriptStartArgs calldata args) public {
        LibTranscript.start(currentGame(), args);
    }

    function register(address participant, bytes calldata profile) public {
        LibTranscript.register(currentGame(), participant, profile);
    }

    function entryCommit(address participant, TranscriptCommitment calldata commitment) public returns (uint256) {
        return LibTranscript.entryCommit(currentGame(), participant, commitment);
    }

    function entryReveal(address advocate, TranscriptOutcome calldata argument) public {
        LibTranscript.entryReveal(currentGame(), advocate, argument);
    }

    function checkRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view returns (bool) {
        return LibTranscript.checkRoot(currentGame(), proof, label, node);
    }
    function verifyRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view {
        LibTranscript.verifyRoot(currentGame(), proof, label, node);
    }
}