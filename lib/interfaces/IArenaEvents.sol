// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "lib/gameid.sol";
import "lib/transcript.sol";

interface IArenaEvents {
    event GameCreated(
        GameID indexed gid,
        TID tid,
        address indexed creator,
        uint256 maxPlayers
    );
    event GameReset(GameID indexed gid, TID tid);
    event GameStarted(GameID indexed gid);
    event GameCompleted(GameID indexed gid);
    event PlayerJoined(GameID indexed gid, address player, bytes profile);
    event PlayerStartLocation(
        GameID indexed gid,
        address player,
        bytes32 startLocation,
        bytes sceneblob
    );

    // NOTE: These are duplicated in library Transcript - this is the only way to expose the abi to ethers.js
    event UseExit(
        GameID indexed gid,
        TEID eid,
        address indexed player,
        ExitUse exitUse
    ); // player is the committer of the tx
    event ExitUsed(
        GameID indexed gid,
        TEID eid,
        address indexed player,
        ExitUseOutcome outcome
    );
    event EntryReject(
        GameID indexed gid,
        TEID eid,
        address indexed player,
        bool halted
    );

    event UseToken(
        GameID indexed gid,
        TEID eid,
        address indexed participant,
        FurnitureUse use
    );
    event FurnitureUsed(
        GameID indexed gid,
        TEID eid,
        address indexed participant,
        FurnitureUseOutcome outcome
    );

    // The following events are emitted by transcript playback to reveal the full narative of the game
    event TranscriptPlayerEnteredLocation(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed entered,
        ExitID enteredVia,
        LocationID left,
        ExitID leftVia
    );

    event TranscriptPlayerKilledByTrap(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed location,
        uint256 furniture
    );

    event TranscriptPlayerDied(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed location,
        uint256 furniture
    );

    event TranscriptPlayerGainedLife(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed location,
        uint256 furniture
    );

    // only when player.lives > 0
    event TranscriptPlayerLostLife(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed location,
        uint256 furniture
    );

    event TranscriptPlayerVictory(
        uint256 indexed gameId,
        TEID eid,
        address indexed player,
        LocationID indexed location,
        uint256 furniture
    );
}
