// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {ERC1155BaseInternal} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol";
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
    ERC1155BaseInternal,
    ModOwnable,
    ModPausable,
    ContextMixin
{
    using LibTranscript for Transcript;

    constructor() {}

    modifier holdsToken(address account, uint256 id) {
        if (_balanceOf(account, id) == 0) revert ModBalanceOf__NotTokenHolder();
        _;
    }

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
    ) public whenNotPaused holdsToken(_msgSender(), gid) {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();

        Transcript storage t = s.games[gid];
        t.entryReveal(_msgSender(), argument);

        // if there was any issue with the proof, entryReveal reverts

        // 1. if the choice type was declared as a victory condition,
        // complete the game and transfer ownership to the participant.
        if (
            LibTranscript.arrayContains(
                t.victoryTransitionTypes,
                argument.proof.transitionType
            )
        ) {
            // complete is an irreversible state, no code exists to
            // 'un-complete'. this method can only be called by the current
            // holder of the game transcript token
            t.complete();

            // ownership transfer *from* the current holder (the guardian)
            // TODO: remember to disperse and release bound tokens appropriately when we do treats
            // see _beforeTokenTransfer in the ERC1155ArenaFacet

            address from = _msgSender();
            _safeTransfer(
                from,
                from,
                argument.participant,
                gid,
                1,
                argument.data
            );
        } else {
            uint256 eid = t.cursors[argument.participant];

            // "reveal" the choices. we say reveal, but he act of including them
            // in the call data has already done that. this just emits the logs
            // signaling proof completion.
            t._revealChoices(
                eid,
                argument.participant,
                argument.proof.leaves[argument.choiceLeafIndex], // XXX: reconsider this in light of enforced stack layout
                argument.data
            );
        }
    }
}
