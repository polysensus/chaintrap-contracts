// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {GameIsInitialised, InvalidProof} from "lib/transcript2.sol";
import {LibGame} from "lib/transcript2.sol";
import {Transcript2, TranscriptInitArgs} from "lib/transcript2.sol";
import {ActionCommitment, OutcomeArgument} from "lib/transcript2.sol";

/*
 TranscriptFactory creates a new Transcript2 storage entry on demand and implements
 forwarders (to the most recently created) for all the LibGame methods that
 require calldata arguments
*/
contract TranscriptFactory {

    Transcript2[] games;

    function pushGame() public {
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

    function forceGameState(LibGame.GameState state) public {
        currentGame().state = state;
    }

    function forceTranscriptEntryOutcome(uint256 tid, LibGame.Outcome outcome) public {
        currentGame().transcript[tid].outcome = outcome;
    }


    // --- LibGame public forwarders
    // These are required to make calldata work 
    function _init(uint256 id, TranscriptInitArgs calldata args) public {
        LibGame._init(currentGame(), id, args);
    }

    function commitAction(address participant, ActionCommitment calldata commitment) public returns (uint256) {
        return LibGame.commitAction(currentGame(), participant, commitment);
    }

    function resolveOutcome(address advocate, OutcomeArgument calldata argument) public {
        LibGame.resolveOutcome(currentGame(), advocate, argument);
    }

    function checkRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view returns (bool) {
        return LibGame.checkRoot(currentGame(), proof, label, node);
    }
    function verifyRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view {
        LibGame.verifyRoot(currentGame(), proof, label, node);
    }
}