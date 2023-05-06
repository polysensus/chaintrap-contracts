// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import "lib/solidstate/security/ModPausable.sol";
import "lib/contextmixin.sol";
import "lib/tokenid.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "lib/transcript.sol";
import "lib/arena/storage.sol";
import "lib/arena/accessors.sol";

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract ArenaTranscriptsFacet is OwnableInternal, ModPausable, ContextMixin {
    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    event GameReset(GameID indexed gid, TID tid);

    constructor() {}

    /// ---------------------------------------------------
    /**
     * @dev This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     * ref: https://docs.opensea.io/docs/polygon-basic-integration
     */
    function _msgSender() internal view returns (address sender) {
        return ContextMixin.msgSender();
    }

    /// ---------------------------------------------------
    /// @dev map & game loading.
    /// these methods are only called after the game
    /// is complete(closed)
    /// ---------------------------------------------------

    function loadLocations(
        GameID gid,
        Location[] calldata locations
    ) public whenNotPaused {
        ArenaAccessors.game(gid).load(locations);
    }

    function loadExits(GameID gid, Exit[] calldata exits) public whenNotPaused {
        return ArenaAccessors.game(gid).load(exits);
    }

    function loadLinks(GameID gid, Link[] calldata links) public whenNotPaused {
        ArenaAccessors.game(gid).load(links);
    }

    function loadTranscriptLocations(
        GameID gid,
        TranscriptLocation[] calldata locations
    ) public whenNotPaused {
        ArenaAccessors.game(gid).load(locations);
    }

    /// @notice if a mistake is made loading the game map reset it using this
    /// method. The game and transcript ids are unchanged
    function reset(GameID gid) public whenNotPaused {
        ArenaAccessors.game(gid).reset();
        emit GameReset(gid, ArenaStorage.layout().gid2tid[gid]);
    }

    /// ---------------------------------------------------
    /// @dev transcript playback
    /// ---------------------------------------------------

    function playTranscript(
        GameID gid,
        TEID cur,
        TEID end
    ) public whenNotPaused returns (TEID) {
        return
            ArenaAccessors.game(gid).playTranscript(
                ArenaAccessors._trans(gid, false),
                ArenaStorage.layout().furniture,
                cur,
                end
            );
    }
}
