// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

// import "@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol";
// import "@solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol";

import "lib/solidstate/token/ERC1155/ModBalanceOf.sol";
import "lib/solidstate/security/ModPausable.sol";
import "lib/solidstate/access/ownable/ModOwnable.sol";

import "lib/contextmixin.sol";

import "lib/interfaces/IArenaTranscript2.sol";

import {LibArena2Storage} from "lib/arena2/storage.sol";
import {LibTranscript, Transcript2, StartGameArgs} from "lib/libtranscript2.sol";

error InsufficientBalance(address addr, uint256 id, uint256 balance);

error ArenaError(uint);

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract ArenaFacet is
    IArenaTranscript2,
    ModOwnable,
    ModPausable,
    ModBalanceOf,
    ContextMixin
{
    using LibTranscript for Transcript2;

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
    /// @dev Transcript2# game setup creation & player signup
    /// ---------------------------------------------------

    /// @notice register a participant (transcript2)
    /// @param profile profile information, not stored on chain but emmited in log of registration
    function registerParticipant(
        uint256 gid,
        bytes calldata profile
    ) public whenNotPaused {
        LibArena2Storage.Layout storage s = LibArena2Storage.layout();
        s.games[gid].registerParticipant(_msgSender(), profile);
    }

    function startGame2(
        uint256 gid,
        StartGameArgs calldata args
    ) public whenNotPaused holdsToken(_msgSender(), gid) {
        LibArena2Storage.Layout storage s = LibArena2Storage.layout();
        s.games[gid].startGame(args);
    }

    function commitAction(
        uint256 gid,
        ActionCommitment calldata commitment
    ) public whenNotPaused returns (uint256) {
        LibArena2Storage.Layout storage s = LibArena2Storage.layout();
        return s.games[gid].commitAction(_msgSender(), commitment);
    }

    function resolveOutcome(
        uint256 gid,
        OutcomeArgument calldata argument
    ) public whenNotPaused {
        LibArena2Storage.Layout storage s = LibArena2Storage.layout();
        s.games[gid].resolveOutcome(_msgSender(), argument);
    }
}
