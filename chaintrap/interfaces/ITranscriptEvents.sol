// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {LibTranscript} from "chaintrap/libtranscript.sol";
import {ProofLeaf} from "chaintrap/libproofstack.sol";

interface ITranscriptEvents {
    event TranscriptCreated(
        uint256 indexed id,
        address indexed creator,
        uint256 registrationLimit
    );
    event TranscriptStarted(uint256 indexed id);
    event TranscriptCompleted(uint256 indexed id);

    /// @dev emitted when a participant is registered
    event TranscriptRegistration(
        uint256 indexed id,
        address indexed participant,
        bytes profile
    );

    /// @dev emited when a root is initialised or changed
    /// @param id the game token
    /// @param label the trie label (because it may be used in many games it is indexed)
    /// @param root the trie root (because it may be used in many games it is indexed)
    event TranscriptMerkleRootSet(
        uint256 indexed id,
        bytes32 indexed label,
        bytes32 indexed root
    );

    /// @dev the choices that were revealed as a consequence of the *previous*
    /// transcript entry. The eid is 0 when setting the starting choices and
    /// data.
    event TranscriptEntryChoices(
        uint256 indexed id,
        address indexed participant,
        uint256 eid,
        ProofLeaf choices,
        bytes data
    );

    /// @dev emitted when a participant commits to a choice.
    /// @param id the transcript token.
    /// @param eid the transcript id, this ties the proposal to a specific transcript entry. hence e id.
    /// @param participant a game participant, any player or the game host.
    /// @param rootLabel the label idenfitying the root for the outcome proof.
    ///  typically this indicates a game action.
    /// @param inputChoice the input selected from the choices available to the participant
    event TranscriptEntryCommitted(
        uint256 indexed id,
        address indexed participant,
        uint256 eid,
        bytes32 rootLabel,
        uint256 inputChoice,
        bytes data
    );

    /// @dev emitted when the transcript creator (or advocate) resolves a pending committed entry
    event TranscriptEntryOutcome(
        uint256 indexed id,
        address indexed participant,
        uint256 eid,
        address advocate,
        bytes32 rootLabel,
        LibTranscript.Outcome outcome,
        bytes data
    );

    /// @dev emitted when the participant makes an individualy terminal choice -
    /// typically a death trap.
    event TranscriptParticipantHalted(
        uint256 indexed id,
        address indexed participant,
        uint256 lastEID
    );

    event TranscriptParticipantLivesAdded(
        uint256 indexed id,
        address indexed participant,
        uint256 lives,
        uint256 added
    );
    event TranscriptParticipantLivesLost(
        uint256 indexed id,
        address indexed participant,
        uint256 lives,
        uint256 lost
    );
}
