// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import "@solidstate/contracts/security/PausableInternal.sol";
import "lib/contextmixin.sol";
import "lib/tokenid.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "./storage.sol";
import "./libaccessors.sol";

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
abstract contract TranscriptsInternal is
    OwnableInternal,
    PausableInternal,
    ContextMixin
    {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    event GameReset(GameID indexed gid, TID tid);

    constructor () { }

    /// ---------------------------------------------------
    /**
     * @dev This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     * ref: https://docs.opensea.io/docs/polygon-basic-integration
     */
    function _msgSender()
        internal
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /// ---------------------------------------------------
    /// @dev map & game loading.
    /// these methods are only called after the game
    /// is complete(closed)
    /// ---------------------------------------------------

    function loadLocations(GameID gid, Location[] calldata locations) public whenNotPaused {
        LibAccessors.game(gid).load(locations);
    }

    function loadExits(GameID gid, Exit[] calldata exits) public whenNotPaused {
        return LibAccessors.game(gid).load(exits);
    }

    function loadLinks(GameID gid, Link[] calldata links) public whenNotPaused {
        LibAccessors.game(gid).load(links);
    }

    function loadTranscriptLocations(GameID gid, TranscriptLocation[]calldata locations) public whenNotPaused {
        LibAccessors.game(gid).load(locations);
    }

    /// @notice if a mistake is made loading the game map reset it using this
    /// method. The game and transcript ids are unchanged
    function reset(GameID gid) public whenNotPaused {

        LibAccessors.game(gid).reset();
        emit GameReset(gid, ChaintrapStorage.layout().gid2tid[gid]);
    }

    /// ---------------------------------------------------
    /// @dev transcript playback
    /// ---------------------------------------------------

    function playTranscript(GameID gid, TEID cur, TEID end) public whenNotPaused returns (TEID) {
        return LibAccessors.game(gid).playTranscript(
            LibAccessors._trans(gid, false), ChaintrapStorage.layout().furniture, cur, end);
    }
}
