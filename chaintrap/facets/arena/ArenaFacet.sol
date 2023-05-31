// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

// import "@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol";
// import "@solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol";

import "lib/solidstate/token/ERC1155/ModBalanceOf.sol";
import "lib/solidstate/security/ModPausable.sol";
import "lib/solidstate/access/ownable/ModOwnable.sol";

import "lib/contextmixin.sol";

import "lib/interfaces/IArenaTranscript.sol";

import {LibArenaStorage} from "lib/arena/storage.sol";
import {LibTranscript, Transcript, TranscriptStartArgs} from "lib/libtranscript.sol";

error InsufficientBalance(address addr, uint256 id, uint256 balance);

error ArenaError(uint);

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract ArenaFacet is
    IArenaTranscript,
    ModOwnable,
    ModPausable,
    ModBalanceOf,
    ContextMixin
{
    using LibTranscript for Transcript;

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
    /// @dev Transcript# game setup creation & player signup
    /// ---------------------------------------------------

    /// @notice register a participant (transcript2)
    /// @param profile profile information, not stored on chain but emmited in log of registration
    function registerTrialist(
        uint256 gid,
        bytes calldata profile
    ) public whenNotPaused {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.games[gid].register(_msgSender(), profile);
    }

    function startTranscript(
        uint256 gid,
        TranscriptStartArgs calldata args
    ) public whenNotPaused holdsToken(_msgSender(), gid) {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.games[gid].start(args);
    }

    function transcriptEntryCommit(
        uint256 gid,
        TranscriptCommitment calldata commitment
    ) public whenNotPaused returns (uint256) {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        return s.games[gid].entryCommit(_msgSender(), commitment);
    }

    function transcriptEntryResolve(
        uint256 gid,
        TranscriptOutcome calldata argument
    ) public whenNotPaused {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.games[gid].entryResolve(_msgSender(), argument);
    }
}
