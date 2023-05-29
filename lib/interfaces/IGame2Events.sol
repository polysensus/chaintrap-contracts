// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {LibTranscript} from "lib/libtranscript2.sol";

interface IGame2Events {
    /// @dev emitted when a merkle root is initialised or changed
    event SetMerkleRoot(
        uint256 indexed id,
        bytes32 indexed label,
        bytes32 indexed root
    );
    event GameCreated(
        uint256 indexed id,
        address indexed creator,
        uint256 maxParticipants
    );

    /// @dev emitted when a participant is registered
    event ParticipantRegistered(
        uint256 indexed id,
        address indexed participant,
        bytes profile
    );

    /// @dev the choices that were revealed as a consequence of the *previous*
    /// transcript entry. The eid is 0 when setting the starting choices and
    /// data.
    event RevealedChoices(
        uint256 indexed id,
        address indexed participant,
        uint256 eid,
        bytes32[] choices,
        bytes data
    );

    /// @dev emitted when an act is proposed.
    /// @param id the game token
    /// @param eid the transcript id, this ties the proposal to a specific game
    ///  turn. Note: this is indexed on the assumption that querying the act & outcome
    ///  for specific game turns is a hot path.
    /// @param rootLabel the label idenfitying the root for the outcome proof.
    ///  typically this indicates a game action.
    /// @param participant a game participant, any player or the game host
    event ActionCommitted(
        uint256 indexed id,
        uint256 indexed eid,
        address indexed participant,
        bytes32 rootLabel,
        bytes32 node,
        bytes data
    );

    event OutcomeResolved(
        uint256 indexed id,
        uint256 indexed eid,
        address indexed participant,
        address advocate,
        bytes32 rootLabel,
        LibTranscript.Outcome outcome,
        bytes32 node,
        bytes data
    );

    // We emit this event just before OutcomeResolved so that there is an index for advocate proofs.
    event ArgumentProven(
        uint256 indexed id,
        uint256 indexed eid,
        address indexed advocate
    );
}
