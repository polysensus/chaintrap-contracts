// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;
import "./errors.sol";
import "./locations.sol";
import "./gameid.sol";

type TID is uint256;
TID constant invalidTID = TID.wrap(0);

type TEID is uint16;
TEID constant invalidTEID = TEID.wrap(0);

/// @dev due to how the enumeration `next` method works, the initial cur value must be 0
TEID constant cursorStart = TEID.wrap(0);

error InvalidTID(uint256 id);

/// @dev errors for transcript entries
error InvalidTranscriptEntry();
error InvalidTEID(uint16 id);
error TEIDNotAnExitUse();
error TEIDNotAnExitUseOutcome();

/// Halted is raised if the player attempts to commit another move after the
/// game master declared them halted.
error Halted(address player);


/// PendingOutcome is raised if the player attempts to commit a move before the
/// previous move has been accepted by the host
error PendingOutcome(address player);

struct Move {
    // Elements common to all transcript entry kinds can go  in here
    address player;
    Transcripts.MoveKind kind;
}

struct Outcome {
    // GameTranscripts.EntryKind kind; kind is obtained from the associated move record

    /// @dev The outcome record is created by the player's initial move.
    /// outcomeDeclared is set to true when the game master process the move and
    /// sets the outcome.

    bool outcomeDeclared;

    // moveAccepted is false if the move was deemed invalid or ileagal
    bool moveAccepted;

    // when the player completes the dungeon, abandons the game, or dies halted
    // is set true.  once all players have halted the transcripts can be checked
    // and any prizes handed out.  Note that not much information leaks as a
    // consequence of everyone seeing when halted goes true.
    bool halted;
}

/// @title enumerating the transcript yeilds entries
struct TranscriptEntry {
    address player;
    Transcripts.MoveKind kind;
    bool halted;
}

/// @dev each Move that changes location generates a new location token They are
/// (or will be) derived as a combination of location-id & blocknumber.  This
/// lets us commit to them in 'allow' without leaking a trace of the map to the
/// chain. We purposefully do _not_ make it unique to the player - so that when
/// two players get matching location tokens we know that they are in the same
/// location at the same time. After the game completes the game master makes a
/// TranscriptionLocation for each location token in the transcript using their
/// copy of the map.
struct TranscriptLocation {
    uint256 blocknumber; // ahh, this may need to be #header
    bytes32 token;
    LocationID id;
    // May want to include game map vrf beta
}

// ---------------------------
// specific move and outcome types
struct ExitUse{
    Locations.SideKind side;
    uint8 egressIndex;
}

struct ExitUseOutcome{

    // location (will eventually be) keccak(location number | blocknumber). So the
    // location tokens do not repeat when the player re-enters the same location
    // and they can only be resolved once the game completes - once the games
    // master reveals all the location numbers. As we follow the map transcript
    // using the revealed map we will obtain the small subset of all locations
    // valid from the players current.
    // The reason we _dont_ include a player uniquenes field is to allow for
    // con-current play. If two players enter the same location on the same
    // block their location tokens will be equal.
    bytes32 location;
    // The (eventualy) encrypted blob for the scene the player is presented with
    // after using the exit. Even without encryption, it does not reveal the
    // structure of the full map, just what is inside a particular room. And
    // there is no way for other players to identify *which* room it is directly
    // from the contents. After sufficient rooms have been visited it might be
    // possible to piece it together automatically but probably not. And by late
    // game it doesn't matter so much.
    bytes sceneblob;
    Locations.SideKind side;
    uint8 ingressIndex;
    bool halt; 
}

struct Transcript {

    // Single transcript for all players so that there is an aggreed move ordering.
    // This is significant if the map state is shared between players.

    Move[]_moves;
    Outcome[]_outcomes;

    // map for every kind of transcript entry so we can have specific types for each
    mapping(TEID => ExitUse) exitUses;
    mapping(TEID => ExitUseOutcome) exitUseOutcomes;
    mapping(address => bool) halted;
    mapping(address => bool) pendingOutcome;

    GameID gid;
}

library Transcripts {

    using Transcripts for Transcript;

    enum MoveKind {
        Undefined,
        ExitUse,
        Invalid
    }

    // NOTE: These are duplicated in contract Arena - this is the only way to expose the abi to ethers.js
    event UseExit(GameID indexed gid, TEID eid, ExitUse); // player is the committer of the tx
    event ExitUsed(GameID indexed gid, TEID eid, address player, ExitUseOutcome);

    /// ---------------------------
    /// @dev state changing methods

    // global initialisation & reset
    function _init(Transcript storage self, GameID gid) internal {
        if (self._moves.length != 0 || self._outcomes.length != 0) {
            revert IsInitialised();
        }
        self._moves.push();
        self._outcomes.push();
        self.gid = gid;
    }

    function reject(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self._outcomes[i].outcomeDeclared = true;
        self._outcomes[i].moveAccepted = false;

        // Record that the players move is no longer pending
        self.pendingOutcome[self._moves[i].player] = false;
    }

    /// @dev typically reject and halt is used to stop griefing
    function rejectAndHalt(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self._outcomes[i].outcomeDeclared = true;
        self._outcomes[i].moveAccepted = false;
        self._outcomes[i].halted = true;
        self.halted[self._moves[i].player] = true;

        // Record that the players move is no longer pending
        self.pendingOutcome[self._moves[i].player] = false;
    }


    function allowAndHalt(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self._outcomes[i].outcomeDeclared = true;
        self._outcomes[i].moveAccepted = true;
        self._outcomes[i].halted = true;
        self.halted[self._moves[i].player] = true;

        // Record that the players move is no longer pending
        self.pendingOutcome[self._moves[i].player] = false;
    }

    /// ---------------------------
    /// @dev Move type specific commit & allow methods

    function _allocMove(Transcript storage self) internal returns (Move storage, TEID) {
        if (self._moves.length >= type(uint16).max) {
            revert IDExhaustion();
        }
        uint16 i = uint16(self._moves.length);
        self._moves.push();
        self._outcomes.push(); // critical that we create this at the same time.

        return (self._moves[i], TEID.wrap(i));
    }

    function commitExitUse(
        Transcript storage self, address player, ExitUse calldata committed) internal returns (TEID) {

        self.requireNotHalted(player);

        // Until the game host confirms or rejects the previous move for this
        // player, another move cannot be made.
        if (self.pendingOutcome[player]) {
            revert PendingOutcome(player);
        }
        self.pendingOutcome[player] = true;

        (Move storage mv, TEID id) = self._allocMove();
        mv.kind = MoveKind.ExitUse;
        mv.player = player;

        ExitUse storage eu = self.exitUses[id];
        eu.side = committed.side;
        eu.egressIndex = committed.egressIndex;


        emit UseExit(self.gid, id, eu); // player is the committer of the tx
        return id;
    }

    function allowExitUse(Transcript storage self, TEID id, ExitUseOutcome calldata outcome) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self._outcomes[i].outcomeDeclared = true;
        self._outcomes[i].moveAccepted = true;
        if (outcome.halt) {
            self._outcomes[i].halted = true;
            self.halted[self._moves[i].player] = true;
        }

        ExitUseOutcome storage o = self.exitUseOutcomes[id];
        o.location = outcome.location;
        o.sceneblob = outcome.sceneblob; // dynamic array copy to storage
        o.side = outcome.side;
        o.ingressIndex = outcome.ingressIndex;
        o.halt = outcome.halt;

        // Record that the players move is no longer pending
        self.pendingOutcome[self._moves[i].player] = false;

        emit ExitUsed(self.gid, id, self._moves[i].player, outcome);
    }

    /// ---------------------------
    /// @dev state reading methods

    function exitUse(Transcript storage self, TEID id) internal view returns (ExitUse storage) {

        ExitUse storage u = self.exitUses[id];
        if (u.side == Locations.SideKind.Undefined) {
            revert TEIDNotAnExitUse();
        }

        return u;
    }

    function exitUseOutcome(Transcript storage self, TEID id) internal view returns (ExitUseOutcome storage) {

        ExitUseOutcome storage o = self.exitUseOutcomes[id];
        if (o.side == Locations.SideKind.Undefined) {
            revert TEIDNotAnExitUse();
        }

        return o;
    }

    /// ---------------------------
    /// @dev transcript enumeration. using an enumeration api so that we don't
    /// need to alocate unbounded memory while checking the transcripts. The key
    /// consideration here is that we skip rejected moves and we indicate when
    /// each player halts.

    /// @dev returns the next allowed transcript item after cur
    /// @param self a parameter just like in doxygen (must be followed by parameter name)
    /// @param cur The callers 'current' transcript entry position
    /// @return - The TEID, TranscriptEntry after cur and a boolean indicating if the enumeration is complete.
    function next(Transcript storage self, TEID cur) internal view returns (TEID, TranscriptEntry memory, bool) {

        TranscriptEntry memory te;
        te.player = address(0);
        te.kind = Transcripts.MoveKind.Undefined;
        te.halted = false;

        TEID id = invalidTEID;

        // Can't use checkedTEIDIndex here because the initial cur will be TEID(0)

        uint16 i = self.checkedTEIDCursorIndex(cur) + 1;

        for (; i < self._outcomes.length; i++) {
            if (self._outcomes[i].outcomeDeclared && self._outcomes[i].moveAccepted) {
                id = TEID.wrap(i);
                te.player = self._moves[i].player;
                te.kind = self._moves[i].kind;
                te.halted = self.halted[te.player];
                break;
            }
        }

        // if the last entry is rejected then we will enter next() and initialise i to 
        // self._outcomems.length due to  cur + 1
        return (id, te, i >= self._outcomes.length - 1);
    }


    // checks and requires
    function requireValidTEID(Transcript storage self, uint16 i) internal view {
        if (i == 0 || i >= self._outcomes.length) {
            revert InvalidTranscriptEntry();
        }
    }

    function requireNotHalted(Transcript storage self, address player) internal view {
        if (self.halted[player] == true) {
            revert Halted(player);
        }
    }

    function checkedTEIDIndex(Transcript storage self, TEID id) internal view returns (uint16) {
        uint16 i = TEID.unwrap(id);
        self.requireValidTEID(i);
        return i;
    }

    function checkedTEIDCursorIndex(Transcript storage self, TEID id) internal view returns (uint16) {

        uint16 i = TEID.unwrap(id);

        // i==0 is cursorStart so can't use requireValidTEID, and also note we
        // require i < self._outcomes.length - 1. The first element in _outcomes
        // is always the 'null' entry, so for the single valid outcome case we
        // will have length==2
        if (!(i < self._outcomes.length - 1)) {
            revert InvalidTEID(i);
        }

        return i;
    }
}