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
import {TRANSCRIPT_CURSOR_HALTED, LibTranscript, Transcript, TranscriptStartArgs} from "lib/libtranscript.sol";

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

        if (
            LibTranscript.arrayContains(
                t._transitionTypes().victoryTransitions,
                argument.proof.transitionType
            )
        ) {
            // 1. if the choice type was declared as a victory condition,
            // complete the game and transfer ownership to the participant.

            // All other participants are trapped in the dungeon.
            t.haltAllExcept(argument.participant);

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
        } else if (
            LibTranscript.arrayContains(
                t._transitionTypes().livesIncrement,
                argument.proof.transitionType
            )
        ) {
            // 3. Add a single life.
            t.trialistAddLives(argument, 1);
        } else if (
            // 4. remove a single life, and halt if the participant lives are exhausted.
            LibTranscript.arrayContains(
                t._transitionTypes().livesDecrement,
                argument.proof.transitionType
            )
        ) {
            // 3. Remove a single life or consume a free life bonus.
            if (!t.trialistApplyFatality(argument)) {
                return; // not fatal
            }
            // then the player ran out of lives
            t.haltParticipant(argument);

            // If all participants are now halted the narrator is victorious
            if (t.countHalted() == t.registered.length) t.complete();
        } else if (
            LibTranscript.arrayContains(
                t._transitionTypes().haltParticipantTransitions,
                argument.proof.transitionType
            )
        ) {
            // 2. if the choice type was declared as a participant halt condition,
            // halt the participant. Note that this by passes lives

            t.haltParticipant(argument);
            // If all participants are now halted the narrator is victorious
            if (t.countHalted() == t.registered.length) t.complete();
        } else {
            // "reveal" the choices. we say reveal, but he act of including them
            // in the call data has already done that. this just emits the logs
            // signaling proof completion.
            t.revealChoices(argument);
        }
    }
}
