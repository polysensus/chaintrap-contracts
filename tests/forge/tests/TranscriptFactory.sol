// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {GameIsInitialised, InvalidProof} from "lib/libtranscript2.sol";
import {LibTranscript, StartGameArgs} from "lib/libtranscript2.sol";
import {Transcript2, TranscriptInitArgs} from "lib/libtranscript2.sol";
import {ActionCommitment, OutcomeArgument} from "lib/libtranscript2.sol";

/*
 TranscriptFactory creates a new Transcript2 storage entry on demand and implements
 forwarders (to the most recently created) for all the LibTranscript methods that
 require calldata arguments
*/
contract TranscriptFactory {

    Transcript2[] games;

    function pushTranscript() public {
        _pushGame();
    }

    function _pushGame() internal returns (Transcript2 storage) {
        uint256 i = games.length;
        games.push();
        return games[i];
    }


    function currentGame() internal view returns (Transcript2 storage) {
        return games[games.length - 1];
    }

    // --- helpers

    function forceGameState(LibTranscript.GameState state) public {
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
    function startGame2(StartGameArgs calldata args) public {
        LibTranscript.startGame(currentGame(), args);
    }

    function registerParticipant(address participant, bytes calldata profile) public {
        LibTranscript.registerParticipant(currentGame(), participant, profile);
    }

    function commitAction(address participant, ActionCommitment calldata commitment) public returns (uint256) {
        return LibTranscript.commitAction(currentGame(), participant, commitment);
    }

    function resolveOutcome(address advocate, OutcomeArgument calldata argument) public {
        LibTranscript.resolveOutcome(currentGame(), advocate, argument);
    }

    function checkRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view returns (bool) {
        return LibTranscript.checkRoot(currentGame(), proof, label, node);
    }
    function verifyRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view {
        LibTranscript.verifyRoot(currentGame(), proof, label, node);
    }
}