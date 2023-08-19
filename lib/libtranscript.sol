// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "hardhat/console.sol";
import "lib/interfaces/ITranscriptErrors.sol";
import {StackProof, ProofLeaf, LibProofStack, ChoiceProof, StackState} from "lib/libproofstack.sol";

/// @dev Transcript records and verifies a series of interactions. Interactions
/// are verified by having encoded them into merkle tries whose roots are
/// commited when the transcript is initialised. A registered participant is
/// offered choices which are leaves on the merkle tries. The available choices
/// for a participant is a product their initial state (establised in `start`)
/// and their previous coices.
///  After `start` subsequent choices are provided when a choice is accepted
/// (and proven) by the transcript creator.
struct Transcript {
    uint256 id;
    address creator;
    LibTranscript.State state;
    /// @dev roots is a mapping from labels to roots. labels can be
    /// keccak(string|bytes) or any value that packs into bytes32. We don't use
    /// strings or bytes because we emit events on change. And the dynamic types
    /// would be hashed anyway then.
    mapping(bytes32 => bytes32) roots;
    /// @dev each entry commitment and outcome is stored in the same transcript
    /// entry. The entry is marked pending when the commitment is made and
    /// accepted or rejected when the outcome declared. entries are allocated
    /// sequentially. We use a map rather than the more obvious array form to
    /// permit the TranscriptEntry field to be changed by upgrades and to allow
    /// it to use enums safely  (diamond storage compatibility).
    mapping(uint256 => TranscriptEntry) transcript;
    /// @dev the id to assign to the next transcript entry. entries are
    /// allocated sequentially.
    uint256 nextEntryId;
    /// @dev each participant has a 'cursor' into the transcript. It refers to
    /// their most recent TranscriptCommitment. Each address is allowed one
    /// outstanding TranscriptCommitment at a time. This prevents registered
    /// from spamming invalid commitments and ensures they must wait for an
    /// entry proof before proceding.
    mapping(address => uint256) cursors;
    /// @dev each participant that is not halted (dead or completed) has an
    /// array of available choices. They are encoded as ProofLeaf's so there
    /// existence can be pre-commited before the game starts. The first set of
    /// choices for a registrant are established when the transcript is started.
    mapping(address => ProofLeaf) choices;
    /// @dev if registrationLimit is 0, registration for a transcript is unlimited.
    uint256 registrationLimit;
    address[] registered;
    // Before participants are expected to register, the guardian must commit to
    // the legitemate choice input, and transition types. And the vari/ous
    // furniture types.
    uint256[] choiceInputTypes;
    uint256[] transitionTypes;
    // At least one victory transition type must be included.
    uint256[] victoryTransitionTypes;
    // halt is probably death, but could be retire if we support that.
    uint256[] haltParticipantTransitionTypes;
}

/// @dev We want the property that curors[participant] != 0 for registered at
/// all times. In register we set the cursor to this value to ensure this.
/// Until, and unless, the first entry is committed, the participants cursor will
/// have this value.
uint256 constant TRANSCRIPT_REGISTRATION_SENTINEL = type(uint256).max;
uint256 constant TRANSCRIPT_CURSOR_HALTED = type(uint256).max - 1;

/// @dev generic description of a game action. It is a commitment because once
/// issued, it can not be taken back.
struct TranscriptCommitment {
    /// @dev choice nodes are resolved against the merkle root identified by
    /// this label.
    bytes32 rootLabel;
    /// @dev each outcome (and the start) provides the next valid set of choices
    /// encoded as ProofLeaf with type and inputs (menu items essentially).  The
    /// player commits by chosing one of those inputs.
    bytes32[] input;
    /// @dev arbitrary application data blob, may be empty. It is emitted in logs but not stored.
    bytes data;
}

/// @dev generic description of an outcome. Outcomes are only accepted if
/// accompanied by a valid proof.
struct TranscriptOutcome {
    /// @dev identifies the participant the outcome affects.
    address participant;
    LibTranscript.Outcome outcome;
    /// @dev proof for the node chosen by the participant
    ChoiceProof proof;
    /// @dev generic data blob which will generaly describe the situation
    /// resulting from the choice proven by the outcome. This data is emitted in
    /// logs but not stored on chain.
    bytes data;
    /// @dev the stack position of the set of choices available to participant for there next
    /// commitment. typically, the data will provide context for these.
    uint256 choiceLeafIndex;
}

/// @dev TranscriptEntry records the commitment and outcome for each entry in the transcript.
struct TranscriptEntry {
    /// @dev the address that issued the TranscriptCommitment
    address participant;
    /// @dev the address that provided the valid TranscriptOutcome proof. We
    /// allow for this to be other than the creator so that we can do
    /// automation.
    address advocate;
    bytes32 rootLabel;
    /// @dev the index of the choice input the participant selected
    uint256 chosenInput;
    LibTranscript.Outcome outcome;
}

struct TranscriptInitArgs {
    /// @dev nft uri for the game token
    string tokenURI;
    /// @dev limits the number of participants. set zero for unlimited.
    uint256 registrationLimit;
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

library LibTranscript {
    /// ---------------------------
    /// @dev overall transcript state

    using LibTranscript for Transcript;

    enum State {
        Unknown,
        Invalid,
        Initialised,
        Started,
        Complete
    }

    // NOTE: These are duplicated in facets due to complications with diamonds & ethers
    /// See ITranscriptEvents.sol for full details of all Transcript* events

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

    event TranscriptParticipantHalted(
        uint256 indexed id,
        address indexed participant,
        uint256 lastEID
    );

    /// @dev emited when a root is initialised or changed
    event TranscriptMerkleRootSet(
        uint256 indexed id,
        bytes32 indexed label,
        bytes32 indexed root
    );

    /// ---------------------------
    /// @dev individual transcript entries (turns)

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
        Outcome outcome,
        bytes data
    );

    enum Outcome {
        Invalid,
        Pending,
        Rejected,
        Accepted
    }

    /// @dev initialise the transcript
    function _init(
        Transcript storage self,
        uint256 id,
        address creator,
        TranscriptInitArgs calldata args
    ) internal {
        // Note the zero'th game is marked Invalid to ensure it can't be initialised
        if (self.state > State.Unknown) revert Transcript_IsInitialised();

        // We require the input types are pre-declared so that the guardian can
        // only resolve choices to outcomes known to the participants on
        // registration. Game stats may include instance counts for traps and so
        // on as a measure of dungeon challenge.
        if (args.choiceInputTypes.length == 0)
            revert Transcript_ChoiceInputTypeRequired();
        if (args.transitionTypes.length < 2)
            // need at least a finish and a normal transition
            // TODO: require they are different values
            revert Transcript_TwoTransitionTypesRequired();
        if (args.victoryTransitionTypes.length == 0)
            // TODO: require they are different values
            revert Transcript_VictoryTransitionTypeRequired();

        self.id = id;
        self.creator = creator;
        self.state = State.Initialised;
        self.nextEntryId = 1;
        self.registrationLimit = args.registrationLimit;

        self.choiceInputTypes = args.choiceInputTypes;
        self.transitionTypes = args.transitionTypes;
        self.victoryTransitionTypes = args.victoryTransitionTypes;
        self.haltParticipantTransitionTypes = args
            .haltParticipantTransitionTypes;

        for (uint i = 0; i < args.roots.length; i++) {
            // Note: solidity reverts for array out of bounds so we don't check for array length equivelence.
            self.roots[args.rootLabels[i]] = args.roots[i];
            emit TranscriptMerkleRootSet(
                self.id,
                args.rootLabels[i],
                args.roots[i]
            );
        }
        emit TranscriptCreated(self.id, creator, args.registrationLimit);
    }

    function register(
        Transcript storage self,
        address participant,
        bytes calldata profile
    ) internal {
        if (self.state != State.Initialised)
            revert Transcript_RegistrationClosed();
        if (self.cursors[participant] != 0)
            revert Transcript_AlreadyRegistered();
        if (
            self.registered.length == self.registrationLimit &&
            self.registrationLimit != 0
        ) revert Transcript_RegistrationFull();

        self.cursors[participant] = TRANSCRIPT_REGISTRATION_SENTINEL;
        self.registered.push(participant);
        emit TranscriptRegistration(self.id, participant, profile);
    }

    function start(
        Transcript storage self,
        TranscriptStartArgs calldata args
    ) internal {
        if (self.state != State.Initialised) revert Transcript_NotReady();
        self.state = State.Started;
        emit TranscriptStarted(self.id);
        for (uint i = 0; i < self.registered.length; i++) {
            // require proof that the initial exit choices are committed to an
            // identified merkle trie.
            bytes32 merkleLeaf = LibProofStack.directMerkleLeaf(
                args.choices[i]
            );
            console.log("merkleLeaf");
            console.logBytes32(merkleLeaf);

            if (!self.checkRoot(args.proofs[i], args.rootLabel, merkleLeaf))
                revert Transcript_InvalidStartChoice();

            self._revealChoices(
                0,
                self.registered[i],
                args.choices[i],
                args.data[i]
            );
        }
    }

    function complete(Transcript storage self) internal {
        if (self.state != State.Started) revert Transcript_NotCompletable();
        self.state = State.Complete;
        emit TranscriptCompleted(self.id);
    }

    /// ---------------------------
    /// @dev actions & outcomes

    function haltParticipant(
        Transcript storage self,
        TranscriptOutcome calldata argument
    ) internal {
        uint256 lastEID = self.cursors[argument.participant];
        self.cursors[argument.participant] = TRANSCRIPT_CURSOR_HALTED;
        emit TranscriptParticipantHalted(
            self.id,
            argument.participant,
            lastEID
        );
        console.log("halted participant %s", argument.participant);
    }

    function _revealChoices(
        Transcript storage self,
        uint256 eid,
        address participant,
        ProofLeaf calldata choices,
        bytes calldata data
    ) internal {
        delete self.choices[participant];
        self.choices[participant] = choices;
        console.log(
            "choices revealed ---- %d %d",
            choices.typeId,
            choices.inputs.length
        );
        emit TranscriptEntryChoices(self.id, participant, eid, choices, data);
    }

    function entryCommit(
        Transcript storage self,
        address participant,
        TranscriptCommitment calldata commitment
    ) internal returns (uint256) {
        // Game state requirements, must be started and not complete.
        if (self.state != State.Started) revert Transcript_NotStarted();

        if (self.roots[commitment.rootLabel] == bytes32(0))
            revert Transcript_InvalidRootLabel();

        if (self.cursors[participant] == 0) revert Transcript_NotRegistered();
        if (self.cursors[participant] == TRANSCRIPT_CURSOR_HALTED)
            revert Transcript_ParticipantHalted();

        // Require that the participant provides a legitemate choice.
        ProofLeaf storage choices = self.choices[participant];
        uint i = 0;
        for (; i < choices.inputs.length; i++) {
            bytes32[] storage input = choices.inputs[i];
            if (input.length != commitment.input.length) continue;

            // Don't allow empty matches.
            if (input.length == 0) continue;

            uint matched = 0;
            for (uint j = 0; j < input.length; j++)
                if (input[j] == commitment.input[j]) matched += 1;
            if (matched == input.length) break;
        }
        if (i == choices.inputs.length) revert Transcript_InvalidChoice();

        // The cursor may not exist yet for the parcipant, or it may exist and
        // it may already be pending or resolved. A participant may not commit a
        // new action until there previous action was resolved. Accepted or
        // Rejected outome values represent resolution.

        TranscriptEntry storage cur = self.transcript[
            self.cursors[participant]
        ];

        // The outcome zero value is Outcome.Invalid. This is what we get if the
        // participant hasn't commited to *any* action yet. Otherwise, the
        // current outcome must be resolved before we allow a new commitment.
        if (cur.outcome == Outcome.Pending) revert Transcript_OutcomePending();

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
        nextEntry.chosenInput = i;
        nextEntry.outcome = Outcome.Pending;

        // Set the registered cursor to the  registered pending entry.
        self.cursors[participant] = eid;

        console.log("comment eid for %s", participant);
        console.logUint(uint(eid));

        emit TranscriptEntryCommitted(
            self.id,
            participant,
            eid,
            commitment.rootLabel,
            i, // nextEntry.chosenInput
            commitment.data
        );
        return eid;
    }

    function arrayContains(
        uint256[] storage array,
        uint256 value
    ) internal view returns (bool) {
        for (uint i = 0; i < array.length; i++)
            if (array[i] == value) return true;
        return false;
    }

    function checkChoiceProof(
        Transcript storage self,
        ChoiceProof calldata proof
    ) internal view {
        if (
            !LibTranscript.arrayContains(
                self.choiceInputTypes,
                proof.choiceSetType
            )
        ) revert Transcript_ChoiceSetTypeInvalid();
        if (
            !LibTranscript.arrayContains(
                self.transitionTypes,
                proof.transitionType
            )
        ) revert Transcript_TransitionTypeInvalid();
    }

    function entryReveal(
        Transcript storage self,
        address advocate,
        TranscriptOutcome calldata argument
    ) internal {
        // Game state requirements, must be started and not complete.
        if (self.state != State.Started) revert Transcript_NotStarted();

        uint256 eid = self.cursors[argument.participant];
        if (eid == 0) revert Transcript_NotRegistered();
        if (eid == TRANSCRIPT_CURSOR_HALTED)
            revert Transcript_ParticipantHalted();

        // require that there are no other participants whose cursors are lower
        // than this one and which have an outcome pending. so that a guardian
        // can't preferentialy advance a particular participant (including self
        // sybils)
        for (uint i = 0; i < self.registered.length; i++) {
            if (self.registered[i] == argument.participant) continue;

            uint256 otherEID = self.cursors[self.registered[i]];
            // two players can't have the same eid because of how they are allocated.
            if (otherEID > eid) continue;

            if (
                self.transcript[otherEID].outcome ==
                LibTranscript.Outcome.Pending
            ) revert Transcript_EarlierPendingOutcomeExists();
        }

        TranscriptEntry storage cur = self.transcript[eid];
        console.log("comment eid for %s", argument.participant);
        console.logUint(uint(eid));

        console.log("outcome");
        console.logUint(uint(cur.outcome));
        console.log("cur.rootLabel");
        console.logBytes32(cur.rootLabel);
        console.log("stack[0].rootLabel");
        console.logBytes32(argument.proof.stack[0].rootLabel);

        if (cur.outcome != LibTranscript.Outcome.Pending)
            revert Transcript_InvalidEntry();

        if (argument.outcome == LibTranscript.Outcome.Accepted) {
            if (argument.proof.stack.length == 0)
                revert Transcript_OutcomeExpectedProof();

            (StackState memory state, bool ok) = LibProofStack.check(
                argument.proof,
                self.roots
            );
            if (!ok) revert Transcript_OutcomeVerifyFailed();

            // Check that one of the proven entries matches the participants
            // commited node AND that the rootLabel was the same for the proof
            // as for the player commit.  For now, we dont impose any semantics
            // on the order or placement of the node in the stack, just that it
            // exists and is labeled correctly - this is insufficient, but more
            // to follow.
            bytes32 choiceLeaf = LibProofStack.directMerkleLeaf(
                self.choices[argument.participant]
            );

            // The choice / consenquent stack semantics require that the first
            // proof is a choice set. Here we require that it is also the choice
            // set that was available to the participant.
            console.log(
                "proven[0] %d = %d ?",
                uint256(state.proven[0]),
                uint256(choiceLeaf)
            );

            if (
                state.proven[0] != choiceLeaf ||
                argument.proof.stack[0].rootLabel != cur.rootLabel
            ) revert Transcript_OutcomeNotProven();

            // The *caller* is responsible for acting on the proof outcome
        } else {
            if (argument.outcome != LibTranscript.Outcome.Rejected)
                revert Transcript_OutcomeIllegal();
        }

        // Reaching here allows the participant to progress and dictates what
        // their next choices are. So we must complete all proofs before doing
        // this.
        cur.outcome = argument.outcome;

        emit TranscriptEntryOutcome(
            self.id,
            cur.participant,
            eid,
            advocate,
            cur.rootLabel,
            cur.outcome,
            argument.data
        );
    }

    /// ---------------------------
    /// @dev proof checking and root maintenance

    function checkProofStack(
        Transcript storage self,
        ChoiceProof calldata proof
    ) internal view returns (bytes32[] memory, bool) {
        (StackState memory state, bool ok) = LibProofStack.check(
            proof,
            self.roots
        );
        return (state.proven, ok);
    }

    /// @dev checkRoot returns true if the proof for the lableled root is correct
    function checkRoot(
        Transcript storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view returns (bool) {
        return MerkleProof.verifyCalldata(proof, self.roots[label], node);
    }

    /// @dev verifyRoot reverts with Transcript_VerifyFailed if the proof for the lableled root is incorrect.
    function verifyRoot(
        Transcript storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view {
        if (!checkRoot(self, proof, label, node))
            revert Transcript_VerifyFailed();
    }
}
