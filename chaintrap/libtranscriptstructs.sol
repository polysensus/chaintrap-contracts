// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @dev general structs for libtranscripts.sol live here
import {ProofLeaf} from "chaintrap/libproofstack.sol";
import {TrialistInitArgs} from "chaintrap/libtrialiststate.sol";

/// @dev the arguments necessary for creating a game.
/// Notice: this struct nests other structs so, due to our use of ERC 2535,
/// cannot be put in an array.
struct TranscriptInitArgs {
    /// @dev nft uri for the game token
    string tokenURI;
    /// @dev limits the number of participants. set zero for unlimited.
    uint256 registrationLimit;
    /// @dev notice: nested struct. DONT store the outer struct in a storage array (incompatible with diamond storage)
    /// The trialist init args are provided when the game is created so they are
    /// known to prospective participants before they register. (So lives cant be set to zero for example)
    TrialistInitArgs trialistArgs;
    /// @dev a rootLabel identifies a root. it can be a string (eg a name), a
    /// token id, an address whatever, it must be keccak hashed if it is a
    /// dynamic type (string or bytes). Note: we don't do bytes or string
    /// because those can't be indexed in log topics.
    bytes32[] rootLabels;
    /// @dev roots is an array of merkle tree roots. each is associated with an entry in rootLabels.
    bytes32[] roots;
    // Before participants are expected to register, the guardian must commit to
    // the legitemate choice input, and transition types. And the various
    // furniture types.
    uint256[] choiceInputTypes;
    uint256[] transitionTypes;
    // At least one victory transition type must be included.
    uint256[] victoryTransitionTypes;
    uint256[] haltParticipantTransitionTypes; // death or retirement
    uint256[] livesIncrement;
    uint256[] livesDecrement;

    // TODO: guardian "house" wins If the game eid reaches this, the game
    // terminates with the guardian victorious.
    // uint256 deadlineEID;
}

struct TranscriptStartArgs {
    /// @dev choices available to each participant at the start of the game.
    /// Each entry is a single ProofLeaf which contains the set of exit choices
    /// available to the registrant at their start location.
    /// The accompanying data
    /// Note: there is some scope for abuse while this can be set arbitrarily
    /// (eg self participation and setting self next to the exit).  When we do
    /// furniture, tricks and treats these will be subject to some controls.
    /// Also, we have yet to add any notion of randomness.
    ProofLeaf[] choices;
    /// @dev data for the particpant starts
    bytes[] data;
    /// @dev the rootLabel and proofs for each of the choices
    bytes32 rootLabel;
    bytes32[][] proofs;
}
