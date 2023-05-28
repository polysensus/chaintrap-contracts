// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {TEID} from "./transcriptid.sol";

import "lib/interfaces/ITranscript2Errors.sol";

/// @dev Transcript2 describes the game session state.
struct Transcript2 {
    uint256 id;
    address creator;
    LibTranscript.GameState state;
    /// @dev roots is a mapping from labels to roots. labels can be
    /// keccak(string|bytes) or any value that packs into bytes32. We don't use
    /// strings or bytes because we emit events on change. And the dynamic types
    /// would be hashed anyway then.
    mapping(bytes32 => bytes32) roots;
    /// @dev each action commitment and outcome argument results in a transcript
    /// entry. entries are allocated sequentially.  using a map rather than the
    /// more obvious array form to permit the TranscriptEntry field to be
    /// changed and to allow it to use enums safely  (diamond storage
    /// compatibility).

    /// @dev the id to assign to the next transcript entry. entries are
    /// allocated sequentially.
    uint256 nextEntryId;
    mapping(uint256 => TranscriptEntry) transcript;
    /// @dev each participant has a 'cursor' into the transcript. It refers to
    /// their most recent ActionCommitment. Each address is allowed one
    /// outstanding ActionCommitment at a time. This prevents participants from
    /// spamming invalid ActionActionCommitments and ensures they must wait for an
    /// advocate proof before proceding.
    mapping(address => uint256) cursors;
    /// @dev each participant that is not halted (dead or completed) has an
    /// array of available choices. The first set of choices are established
    /// before the game starts.
    mapping(address => bytes32[]) choices;
    uint256 maxParticipants;
    address[] participants;
}

/// @dev We want the property that curors[participant] != 0 for participants at
/// all times. In joinGame we set the players cursor to this value to ensure
/// this.  Until, and unless, they commit to their first turn, their cursor will
/// have this value.
uint256 constant TRANSCRIPT_REGISTRATION_SENTINEL = type(uint256).max;

/// @dev generic description of a game action. It is a commitment because once
/// issued, it can not be taken back.
struct ActionCommitment {
    /// @dev actions are resolved against a merkle root. Typically the rootLabel
    /// indicates some action, eg "keccak(Chaintrap:MapLinks)" proving a map
    /// location transition is valid. The game creator the proves the outcome of
    /// the action using their trie data for the corresponding rootLabel
    bytes32 rootLabel;
    /// @dev each outcome argument provides the next valid set of choice nodes.
    /// the guardian must be able to provide an inclusion proof for all choice
    /// nodes it supplies. The first set of choices is bootstrapped when the
    /// guardian sets the player start scene
    bytes32 node;
    bytes data;
}

/// @dev generic description of a game action outcome. It is an argument because
/// outcomes are only accepted if accompanied by a valid proof.
/// in the transcript.
struct OutcomeArgument {
    address participant;
    LibTranscript.Outcome outcome;
    /// @dev generic data blob which will generaly describe the situation
    /// resulting from the choice proven by the argument. for location change
    /// outcomes, data will contain the scene reached which will include the new
    /// set of reachable nodes.
    bytes data;
    /// @dev proof for the node chosen by the participant
    bytes32[] proof;
    /// @dev each entry is a node that may be commited to in the *next* move
    bytes32[] choices;
}

/// @dev TranscriptEntry records the action and outcome for each turn in a game.
struct TranscriptEntry {
    /// @dev the address that issued the ActionCommitment
    address participant;
    /// @dev the address that provided the valid OutcomeArgument proof. TODO consider just emiting this in logs rather than recording on chain
    address advocate;
    bytes32 rootLabel;
    /// @dev node is selected by the player from the scene, the guardian must supply an inclusion proof in the resolution.
    bytes32 node;
    LibTranscript.Outcome outcome;
}

struct TranscriptInitArgs {
    /// @dev nft uri for the game token
    string tokenURI;
    uint256 maxParticipants;
    /// @dev a rootLabel identifies a root. it can be a string (eg a name), a
    /// token id, an address whatever, it must be keccak hashed if it is a
    /// dynamic type (string or bytes). Note: we don't do bytes or string
    /// because those can't be indexed in log topics.
    bytes32[] rootLabels;
    /// @dev roots is an array of merkle tree roots. each is associated with an entry in rootLabels.
    bytes32[] roots;
}

struct StartGameArgs {
    /// @dev choices available to each participant at the start of the game.
    /// Note: there is some scope for guardian abuse while this can be set
    /// arbitrarily (eg self participation and setting self next to the exit).
    /// When we do furniture, tricks and treats these will be subject to some
    /// controls. Also, we have yet to add any notion of randomness.
    bytes32[][] choices;
    /// @dev data for the particpant starts
    bytes[] data;
}

library LibTranscript {
    /// ---------------------------
    /// @dev overall game state

    using LibTranscript for Transcript2;

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

    event GameCreated(
        uint256 indexed id,
        address indexed creator,
        uint256 maxParticipants
    );
    event GameStarted(uint256 indexed id);
    event GameCompleted(uint256 indexed id);

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

    /// @dev emitted when a participant is registered
    // TODO: rename profile -> data
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
    ///  TODO: re-consider whether it is useful to index this
    /// @param participant a game participant, any player or the game host.
    /// @param rootLabel the label idenfitying the root for the outcome proof.
    ///  typically this indicates a game action.
    /// @param node one of the move nodes, provided in the scene presented to
    /// the player by the guardian. In resolving the move, the guardian must
    /// provide a proof of inclusion in the trie identified by rootLabel
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
        Outcome outcome,
        bytes32 node,
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
        address creator,
        TranscriptInitArgs calldata args
    ) internal {
        // Note the zero'th game is marked Invalid to ensure it can't be initialised
        if (self.state > GameState.Unknown) revert GameIsInitialised();
        self.id = id;
        self.creator = creator;
        self.state = GameState.Initialised;
        self.nextEntryId = 1;
        self.maxParticipants = args.maxParticipants;

        for (uint i = 0; i < args.roots.length; i++) {
            // Note: solidity reverts for array out of bounds so we don't check for array length equivelence.
            self.roots[args.rootLabels[i]] = args.roots[i];
            emit SetMerkleRoot(self.id, args.rootLabels[i], args.roots[i]);
        }
        emit GameCreated(self.id, creator, args.maxParticipants);
    }

    function registerParticipant(
        Transcript2 storage self,
        address participant,
        bytes calldata profile
    ) internal {
        if (self.state != GameState.Initialised) revert RegistrationIsClosed();
        if (self.cursors[participant] != 0) revert AlreadyRegistered();
        if (self.participants.length == self.maxParticipants)
            revert LibTranscript2_GameFull();

        self.cursors[participant] = TRANSCRIPT_REGISTRATION_SENTINEL;
        self.participants.push(participant);
        emit ParticipantRegistered(self.id, participant, profile);
    }

    function startGame(
        Transcript2 storage self,
        StartGameArgs calldata args
    ) internal {
        if (self.state != GameState.Initialised) revert GameIsNotStartable();
        self.state = GameState.Started;
        emit GameStarted(self.id);
        for (uint i = 0; i < self.participants.length; i++) {
            self.revealChoices(
                0,
                self.participants[i],
                args.choices[i],
                args.data[i]
            );
        }
    }

    function completeGame(Transcript2 storage self) internal {
        if (self.state != GameState.Started) revert GameIsNotCompletable();
        self.state = GameState.Complete;
        emit GameCompleted(self.id);
    }

    /// ---------------------------
    /// @dev actions & outcomes

    function revealChoices(
        Transcript2 storage self,
        uint256 eid,
        address participant,
        bytes32[] calldata choices,
        bytes calldata data
    ) internal {
        delete self.choices[participant];
        self.choices[participant] = choices;
        emit RevealedChoices(self.id, participant, eid, choices, data);
    }

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

        bytes32[] storage choices = self.choices[participant];
        uint i = 0;
        for (; i < choices.length; i++)
            if (choices[i] == commitment.node) break;
        if (i == choices.length) revert InvalidChoice();

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

        TranscriptEntry storage nextEntry = self.transcript[eid];

        nextEntry.participant = participant;
        nextEntry.rootLabel = commitment.rootLabel;
        nextEntry.node = commitment.node;
        nextEntry.outcome = Outcome.Pending;

        // Set the participants cursor to the  participants pending entry.
        self.cursors[participant] = eid;

        emit ActionCommitted(
            self.id,
            eid,
            participant,
            commitment.rootLabel,
            commitment.node,
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

        if (
            cur.node == bytes32(0) ||
            cur.outcome != LibTranscript.Outcome.Pending
        ) revert InvalidTranscript2Entry();

        if (argument.outcome == LibTranscript.Outcome.Accepted) {
            if (argument.proof.length == 0)
                revert ArgumentInvalidExpectedProof();
            if (
                !LibTranscript.checkRoot(
                    self,
                    argument.proof,
                    cur.rootLabel,
                    cur.node
                )
            ) revert ArgumentInvalidProofFailed();

            self.revealChoices(
                eid,
                argument.participant,
                argument.choices,
                argument.data
            );
        } else {
            if (argument.outcome != LibTranscript.Outcome.Rejected)
                revert ArgumentInvalidIllegalOutcome();
        }

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
            cur.node,
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
