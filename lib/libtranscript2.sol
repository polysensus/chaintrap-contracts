// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {TEID} from "./transcriptid.sol";

import "lib/interfaces/ITranscript2Errors.sol";

/// @dev Transcript2 describes the game session state.
struct Transcript2 {
    uint256 id;
    LibTranscript.GameState state;
    /// @dev roots is a mapping from labels to roots. labels can be
    /// keccak(string|bytes) or any value that packs into bytes32. We don't use
    /// strings or bytes because we emit events on change. And the dynamic types
    /// would be hashed anyway then.
    mapping(bytes32 => bytes32) roots;
    /// @dev each action is recorded in the transcript. entries are allocated sequentially.
    /// @dev using a map rather than the more obvious array form to permit the
    /// TranscriptEntry field to be changed and to allow it to use enums safely

    /// @dev the id to assign to the next transcript entry. entries are
    /// allocated sequentially.
    uint256 nextEntryId;
    mapping(uint256 => TranscriptEntry) transcript;
    /// @dev each participant has a 'cursor' into the transcript. It refers to
    /// their most recent ActionCommitment. Each address is allowed one
    /// outstanding ActionCommitment at a time. This prevents participants from
    /// spamming invalid ActionCommitments and ensures they must wait for an
    /// advocate proof before proceding.
    mapping(address => uint256) cursors;

    /// @dev make curors enumerable
    // address[] participants;
}

/// @dev We want the property that curors[participant] != 0 for participants at
/// all times. In joinGame we set the players cursor to this value to ensure
/// this.  Until, and unless, they commit to their first turn, their cursor will
/// have this value
uint256 constant TRANSCRIPT_REGISTRATION_SENTINEL = type(uint256).max;

/// @dev generic description of a game action. It is a commitment because once
/// issued, it can not be taken back.
struct ActionCommitment {
    /// @dev actions are resolved against a merkle root. Typically the rootLabel
    /// indicates some action, eg "keccak(Chaintrap:MapLinks)" proving a map
    /// location transition is valid. The game creator the proves the outcome of
    /// the action using their trie data for the corresponding rootLabel
    bytes32 rootLabel;
    /// @dev the proposed node, the participant can have enough information to
    /// hand to put together a leaf without fully revealing the game
    bytes32 node;
    bytes data;
}

/// @dev generic description of a game action outcome. It is an argument because
/// outcomes are only accepted if accompanied by a valid proof. Depending on the
/// action that could be either a proof of validity or a proof of exclusion
/// (invalidity). If the argument is accepted, the code & coutcome are recorded
/// in the transcript.
struct OutcomeArgument {
    address participant;
    LibTranscript.Outcome outcome;
    bytes data;
    // XXX: TODO think we need rootLabel too
    bytes32[] proof;
    /// @dev for proofs of exclusion, proof verifies *inclusion* of a
    /// *different* node and its sibling such that node < x < proof[0] || node >
    /// x > proof[0]. As the tree is balanced and sorted (complete) this makes
    /// it impossible for commitment.node to be present in the tree. This
    /// case is indicated when node != commitment.node.
    bytes32 node;
}

/// @dev TranscriptEntry records the action and outcome for each turn in a game.
struct TranscriptEntry {
    // XXX: TODO consider making this a has commitment to increase generality and reduce the storage use. eg
    //  H(abi.encodePacked(participant . rootLabel . node)) -> commitment
    // Then in verify the advocate must supply an argument where
    //  H(abi.encodePacked(argument.participant, argument.node, argument.rootLabel))
    // show that
    /// @dev the address that issued the ActionCommitment
    address participant;
    /// @dev the address that provided the valid OutcomeArgument proof. TODO consider just emiting this in logs rather than recording on chain
    address advocate;
    bytes32 rootLabel;
    bytes32 node;
    LibTranscript.Outcome outcome;
}

struct TranscriptInitArgs {
    /// @dev nft uri for the game token
    string tokenURI;
    /// @dev a rootLabel identifies a root. it can be a string (eg a name), a
    /// token id, an address whatever, it must be keccak hashed if it is a
    /// dynamic type (string or bytes). Note: we don't do bytes or string
    /// because those can't be indexed in log topics.
    bytes32[] rootLabels;
    /// @dev roots is an array of merkle tree roots. each is associated with an entry in rootLabels.
    bytes32[] roots;

    // TODO: consider aliases for rootLabels so we can have many 2: 1 for action encoding.
    // [keccack("Chaintrap:MapLinks"), keccack("Chaintrap:UseExit"), keccack("Chaintrap:FinalExit")]
}

library LibTranscript {
    /// ---------------------------
    /// @dev overall game state

    enum GameState {
        Unknown,
        Invalid,
        Initialised,
        Started,
        Complete
    }

    /// ---------------------------
    /// @dev individual game moves (turns)

    enum Outcome {
        Invalid,
        Pending,
        Rejected,
        Accepted
    }

    /// @dev emitted when a participant is registered
    event ParticipantRegistered(
        uint256 indexed id,
        address indexed participant,
        bytes profile
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
        bytes data
    );

    event OutcomeResolved(
        uint256 indexed id,
        uint256 indexed eid,
        address indexed participant,
        address advocate,
        bytes32 rootLabel,
        Outcome outcome,
        bytes data
    );

    // We emit this event just before OutcomeResolved so that there is an index for advocate proofs.
    event ArgumentProven(
        uint256 indexed id,
        uint256 indexed eid,
        address indexed advocate
    );

    /// ---------------------------
    /// @dev proof checking and root maintenance

    // NOTE: These are duplicated in facets - this is the only way to expose the abi to ethers.js

    /// @dev emited when a root is initialised or changed
    /// @param id the game token
    /// @param label the trie label (because it may be used in many games it is indexed)
    /// @param root the trie root (because it may be used in many games it is indexed)
    /// TODO consider bytes32 repalced which will have the previous root if the
    /// event indicates a previously initialised root is being changed.
    event SetMerkleRoot(
        uint256 indexed id,
        bytes32 indexed label,
        bytes32 indexed root
    );

    /// ---------------------------
    /// @dev overall game state

    /// @dev initialise game storage
    function _init(
        Transcript2 storage self,
        uint256 id,
        TranscriptInitArgs calldata args
    ) internal {
        // Note the zero'th game is marked Invalid to ensure it can't be initialised
        if (self.state > GameState.Unknown) revert GameIsInitialised();
        self.id = id;
        self.state = GameState.Initialised;
        self.nextEntryId = 1;

        for (uint i = 0; i < args.roots.length; i++) {
            // Note: solidity reverts for array out of bounds so we don't check for array length equivelence.
            self.roots[args.rootLabels[i]] = args.roots[i];
            emit SetMerkleRoot(self.id, args.rootLabels[i], args.roots[i]);
        }
    }

    function registerParticipant(
        Transcript2 storage self,
        address participant,
        bytes calldata profile
    ) internal {
        if (self.state != GameState.Initialised) revert RegistrationIsClosed();
        if (self.cursors[participant] != 0) revert AlreadyRegistered();

        self.cursors[participant] = TRANSCRIPT_REGISTRATION_SENTINEL;
        emit ParticipantRegistered(self.id, participant, profile);
    }

    /// ---------------------------
    /// @dev actions & outcomes

    function commitAction(
        Transcript2 storage self,
        address participant,
        ActionCommitment calldata commitment
    ) internal returns (uint256) {
        // Game state requirements, must be started and not complete.
        if (self.state != GameState.Started) revert GameIsNotStarted();

        if (self.roots[commitment.rootLabel] == bytes32(0))
            revert InvalidRootLabel();

        if (self.cursors[participant] == 0) revert NotRegistered();

        // The cursor may not exist yet for the parcipant, or it may exist and
        // it may already be pending or resolved. A participant may not commit a
        // new action until there previous action was resolved.

        TranscriptEntry storage cur = self.transcript[
            self.cursors[participant]
        ];

        // The outcome zero value is Outcome.Invalid. This is what we get if the
        // participant hasn't commited to *any* action yet. Otherwise, the
        // current outcome must be resolved before we allow a new commitment.
        if (cur.outcome == Outcome.Pending) revert OutcomePending();

        // Each valid commitment increments the transcript id. The transcript id
        // needs to be allocated when the participant commits to ensure the
        // outcome verifier can't manipulate the order of events to their
        // advantaage. Being a valid commitment just means it is syntactically
        // correct. It is valid to commit to an ileagal move. A key reason we
        // allow only one outstanding commit per participant is to mitigate
        // 'invalid move spam' in the transcript.
        uint256 eid = self.nextEntryId++;

        self.transcript[eid] = TranscriptEntry(
            participant,
            address(0),
            commitment.rootLabel,
            commitment.node,
            Outcome.Pending
        );

        // Set the participants cursor to the  participants pending entry.
        self.cursors[participant] = eid;

        emit ActionCommitted(
            self.id,
            eid,
            participant,
            commitment.rootLabel,
            commitment.data
        );
        return eid;
    }

    function resolveOutcome(
        Transcript2 storage self,
        address advocate,
        OutcomeArgument calldata argument
    ) internal {
        // Game state requirements, must be started and not complete.
        if (self.state != GameState.Started) revert GameIsNotStarted();

        uint256 eid = self.cursors[argument.participant];
        if (eid == 0) revert InvalidParticipant();

        TranscriptEntry storage cur = self.transcript[eid];

        if (cur.outcome == LibTranscript.Outcome.Invalid)
            revert InvalidTranscriptEntry();

        if (
            argument.outcome == LibTranscript.Outcome.Invalid ||
            argument.outcome == LibTranscript.Outcome.Pending
        ) revert ArgumentInvalidIllegalOutcome();

        // If we are arguing for Accepted, the argument must be a proof of
        // inclusion and node must equal the committed transcript entry.
        if (
            argument.outcome == LibTranscript.Outcome.Accepted &&
            argument.node != cur.node
        ) revert ArgumentInvalidAcceptedMustBeProofOfInclusion();

        if (
            argument.outcome == LibTranscript.Outcome.Rejected &&
            argument.node == cur.node
        ) revert ArgumentInvalidRejectedMustBeProofOfExclusion();

        if (
            !LibTranscript.checkRoot(
                self,
                argument.proof,
                cur.rootLabel,
                argument.node
            )
        ) revert ArgumentInvalidProofFailed();

        cur.outcome = argument.outcome;

        // Note: the order and adjacency of these event emits is part of the
        // external interface. clients are free to assume OutcomeResolved
        // immediately follows ArgumentProven
        emit ArgumentProven(self.id, eid, advocate);
        emit OutcomeResolved(
            self.id,
            eid,
            cur.participant,
            advocate,
            cur.rootLabel,
            cur.outcome,
            argument.data
        );
    }

    /// ---------------------------
    /// @dev proof checking and root maintenance

    /// @dev checkRoot returns true if the proof for the lableled root is correct
    function checkRoot(
        Transcript2 storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view returns (bool) {
        return MerkleProof.verifyCalldata(proof, self.roots[label], node);
    }

    /// @dev verifyRoot reverts with InvalidProof if the proof for the lableled root is incorrect.
    function verifyRoot(
        Transcript2 storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view {
        if (!checkRoot(self, proof, label, node)) revert InvalidProof();
    }
}
