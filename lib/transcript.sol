// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "./errors.sol";
import "./locations.sol";
import "./furnishings.sol";
import "./gameid.sol";

type TID is uint256;
TID constant invalidTID = TID.wrap(0);

type TEID is uint16;
TEID constant invalidTEID = TEID.wrap(0);

/// @dev due to how the enumeration `next` method works, the initial cur value must be 0
TEID constant cursorStart = TEID.wrap(0);
TEID constant cursorUntilEnd = TEID.wrap(0);

error InvalidTID(uint256 id);

/// @dev errors for transcript entries
error InvalidTranscriptEntry();
error InvalidTEID(uint16 id);
error TEIDNotAnExitUse(uint16 id);
error TEIDNotAnExitUseOutcome(uint16 id);
error TEIDNotAFurnitureUse(uint16 id);
error TEIDNotAFurnitureUseOutcome(uint16 id);

/// Halted is raised if the player attempts to commit another move after the
/// game master declared them halted.
error Halted(address player);


/// PendingOutcome is raised if the player attempts to commit a move before the
/// previous move has been accepted by the host
error PendingOutcome(address player);

struct Commitment {

    // Player commitment, the values are commited by the participant
    address player;
    Transcripts.MoveKind kind;

    // Game owner commitment, the values are committed by the game master.

    /// @dev The outcome record is created by the player's initial move.
    /// outcomeDeclared is set to true when the game master process the move and
    /// sets the outcome.

    bool outcomeDeclared;

    /// @dev moveAccepted is false if the move was deemed invalid or ileagal
    bool moveAccepted;

    /// @dev when the player completes the dungeon, abandons the game, or dies halted
    /// is set true.  once all players have halted the transcripts can be checked
    /// and any prizes handed out.  Note that not much information leaks as a
    /// consequence of everyone seeing when halted goes true.
    bool halted;
}

/// @dev each Move that changes location generates a new location token
struct TranscriptLocation {
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

// FurnitureUse represents either a player or a game host playing a token 'card'
// The 
struct FurnitureUse {
    bytes32 token; // this is an opaque salted & blinded value, *not* an nft or fungible
}

struct FurnitureUseOutcome {
    // transfer, victory, death etc
    Furnishings.Kind kind;
    Furnishings.Effect effect;
    bytes blob;
    bool halt;
    // It is not necessary to include the location is not necessary. The players
    // current location is considered when validating the outcome, and it is
    // used to derive the placement token.  So if the outcome is illegal for the
    // players location, it will naturaly fail.
}

struct Transcript {

    // Single transcript for all players so that there is an aggreed move ordering.
    // This is significant if the map state is shared between players.

    Commitment[]entries;

    // map for every kind of transcript entry so we can have specific types for each
    mapping(TEID => ExitUse) exitUses;
    mapping(TEID => ExitUseOutcome) exitUseOutcomes;
    mapping(TEID => FurnitureUse) furnitureUses;
    mapping(TEID => FurnitureUseOutcome) furnitureUseOutcomes;

    mapping(address => TEID) halted;
    mapping(address => bool) pendingOutcome;

    GameID gid;
}

library Transcripts {

    using Transcripts for Transcript;

    enum MoveKind {
        Undefined,
        ExitUse,
        FurnitureUse,
        Invalid
    }

    enum FurnitureUseEffect {
        Undefined,
        Victory,
        Death,
        Transfer

        // XXX: Damage & Bonus etc require an acceptable random oracle. For now we are russian roulette style
    }

    // NOTE: These are duplicated in contract Arena - this is the only way to expose the abi to ethers.js
    event UseExit(GameID indexed gid, TEID eid, address indexed player, ExitUse exitUse); // player is the committer of the tx
    event ExitUsed(GameID indexed gid, TEID eid, address indexed player, ExitUseOutcome outcome);
    event EntryReject(GameID indexed gid, TEID eid, address indexed player, bool halted);

    event UseToken(GameID indexed gid, TEID eid, address indexed player, FurnitureUse use);
    event FurnitureUsed(GameID indexed gid, TEID eid, address indexed player, FurnitureUseOutcome outcome);

    /// ---------------------------
    /// @dev state changing methods

    // global initialisation & reset
    function _init(Transcript storage self, GameID gid) internal {
        if (self.entries.length != 0) {
            revert IsInitialised();
        }
        self.entries.push();
        self.gid = gid;
    }

    function haltedAt(Transcript storage self, address player) internal view returns (TEID) {
        return self.halted[player];
    }

    function reject(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self.entries[i].outcomeDeclared = true;
        self.entries[i].moveAccepted = false;

        // Record that the players move is no longer pending
        self.pendingOutcome[self.entries[i].player] = false;

        emit EntryReject(self.gid, id, self.entries[i].player, false /*halted*/);
    }

    /// @dev typically reject and halt is used to stop griefing
    function rejectAndHalt(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self.entries[i].outcomeDeclared = true;
        self.entries[i].moveAccepted = false;
        self.entries[i].halted = true;
        self.halted[self.entries[i].player] = id;

        // Record that the players move is no longer pending
        self.pendingOutcome[self.entries[i].player] = false;
        emit EntryReject(self.gid, id, self.entries[i].player, true /*halted*/);
    }


    function allowAndHalt(Transcript storage self, TEID id) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self.entries[i].outcomeDeclared = true;
        self.entries[i].moveAccepted = true;
        self.entries[i].halted = true;
        self.halted[self.entries[i].player] = id;

        // Record that the players move is no longer pending
        self.pendingOutcome[self.entries[i].player] = false;
    }

    /// ---------------------------
    /// @dev Move type specific commit & allow methods

    function _allocMove(Transcript storage self) internal returns (Commitment storage, TEID) {
        if (self.entries.length >= type(uint16).max) {
            revert IDExhaustion();
        }
        uint16 i = uint16(self.entries.length);
        self.entries.push();

        return (self.entries[i], TEID.wrap(i));
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

        (Commitment storage co, TEID id) = self._allocMove();
        co.kind = MoveKind.ExitUse;
        co.player = player;

        ExitUse storage eu = self.exitUses[id];
        eu.side = committed.side;
        eu.egressIndex = committed.egressIndex;


        emit UseExit(self.gid, id, player, eu); // player is the committer of the tx
        return id;
    }

    function allowExitUse(Transcript storage self, TEID id, ExitUseOutcome calldata outcome) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self.entries[i].outcomeDeclared = true;
        self.entries[i].moveAccepted = true;
        if (outcome.halt) {
            self.entries[i].halted = true;
            self.halted[self.entries[i].player] = id;
        }

        ExitUseOutcome storage o = self.exitUseOutcomes[id];
        o.location = outcome.location;
        o.sceneblob = outcome.sceneblob; // dynamic array copy to storage
        o.side = outcome.side;
        o.ingressIndex = outcome.ingressIndex;
        o.halt = outcome.halt;

        // Record that the players move is no longer pending
        self.pendingOutcome[self.entries[i].player] = false;

        emit ExitUsed(self.gid, id, self.entries[i].player, outcome);
    }

    function commitFurnitureUse(
        Transcript storage self, address player, FurnitureUse calldata committed) internal returns (TEID) {

        self.requireNotHalted(player);

        // Until the game host confirms or rejects the previous move for this
        // player, another move cannot be made.
        if (self.pendingOutcome[player]) {
            revert PendingOutcome(player);
        }
        self.pendingOutcome[player] = true;

        (Commitment storage co, TEID id) = self._allocMove();
        co.kind = MoveKind.FurnitureUse;
        co.player = player;

        FurnitureUse storage tu = self.furnitureUses[id];
        tu.token = committed.token;

        emit UseToken(self.gid, id, player, tu); // player is the committer of the tx
        return id;
    }

    function allowFurnitureUse(Transcript storage self, TEID id, FurnitureUseOutcome calldata outcome) internal {
        uint16 i = self.checkedTEIDIndex(id);

        self.entries[i].outcomeDeclared = true;
        self.entries[i].moveAccepted = true;
        if (outcome.halt) {
            self.entries[i].halted = true;
            self.halted[self.entries[i].player] = id;
        }

        // XXX: TODO: Transcripts.FurnitureUseEffect.Transfer

        FurnitureUseOutcome storage o = self.furnitureUseOutcomes[id];
        o.blob = outcome.blob;
        o.kind = outcome.kind;
        o.effect = outcome.effect;
        o.halt = outcome.halt;

        // Record that the players move is no longer pending
        self.pendingOutcome[self.entries[i].player] = false;

        emit FurnitureUsed(self.gid, id, self.entries[i].player, outcome);
    }

    /// ---------------------------
    /// @dev state reading methods

    function exitUse(Transcript storage self, TEID id) internal view returns (ExitUse storage) {

        ExitUse storage u = self.exitUses[id];
        if (u.side == Locations.SideKind.Undefined) {
            revert TEIDNotAnExitUse(TEID.unwrap(id));
        }

        return u;
    }

    function exitUseOutcome(Transcript storage self, TEID id) internal view returns (ExitUseOutcome storage) {

        ExitUseOutcome storage o = self.exitUseOutcomes[id];
        if (o.side == Locations.SideKind.Undefined) {
            revert TEIDNotAnExitUse(TEID.unwrap(id));
        }

        return o;
    }

    function furnitureUse(Transcript storage self, TEID id) internal view returns (FurnitureUse storage) {

        FurnitureUse storage u = self.furnitureUses[id];
        if (u.token == 0) {
            revert TEIDNotAFurnitureUse(TEID.unwrap(id));
        }
        return u;
    }

    function furnitureUseOutcome(Transcript storage self, TEID id) internal view returns (FurnitureUseOutcome storage) {

        FurnitureUseOutcome storage o = self.furnitureUseOutcomes[id];
        if (o.effect == Furnishings.Effect.Undefined) {
            revert TEIDNotAFurnitureUse(TEID.unwrap(id));
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
    function next(Transcript storage self, TEID cur) internal view returns (TEID, Commitment storage, bool, bool) {

        TEID id = invalidTEID;
        bool halted = false;
        Commitment storage co = self.entries[0]; // this is the undefined entry

        // Can't use checkedTEIDIndex here because the initial cur will be TEID(0)

        uint16 i = self.checkedTEIDCursorIndex(cur) + 1;
        for (; i < self.entries.length; i++) {
            co = self.entries[i];
            if (co.outcomeDeclared && co.moveAccepted) {
                id = TEID.wrap(i);
                halted = (TEID.unwrap(self.halted[co.player]) == i);
                break;
            }
        }

        // if the last entry is rejected then we will enter next() and initialise i to 
        // self._outcomems.length due to  cur + 1
        return (id, co, halted, i >= self.entries.length - 1);
    }


    // checks and requires
    function requireValidTEID(Transcript storage self, uint16 i) internal view {
        if (i == 0 || i >= self.entries.length) {
            revert InvalidTranscriptEntry();
        }
    }

    function requireNotHalted(Transcript storage self, address player) internal view {
        if (TEID.unwrap(self.halted[player]) != 0) {
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
        // require i < self.entries.length - 1. The first element in _outcomes
        // is always the 'null' entry, so for the single valid outcome case we
        // will have length==2
        if (!(i < self.entries.length - 1)) {
            revert InvalidTEID(i);
        }

        return i;
    }
}