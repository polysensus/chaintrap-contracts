// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;
import "./transcript.sol";
import "./mapstructure.sol";
import "./gameid.sol";


struct Player {
    address addr;
    /// LocationID Current location of the player
    LocationID loc;
    bytes32 startLocation;
    bytes sceneblob;
    /// player profile data, opaque to the contract
    bytes profile;
    bool halted;
}

struct Game {

    Map map;
    Player[] players;
    mapping(address => uint8) iplayers;

    // The game transcript locations are tokens. The preimages for which are
    // required to check the transcript
    bytes32[] locationTokens;
    mapping (bytes32 => uint16) tokenLocations;

    /// The creator of the game gets a payout provide the game is completed by
    /// at least one player.
    address creator;

    /// The 'dungeon' master (often the creator) reveals the result of each player move.
    address master;

    /// maximum number of players
    uint maxPlayers;
    bool started;
    bool completed;
}

/// @dev Invalid* errors are raised for ids can't be mapped to their respective items.
error InvalidPlayer(address player);
error InvalidPlayerIndex(uint8 player);
error InvalidLocationToken(bytes32 token);
error InvalidTranscriptLocation(bytes32 token, uint16 location);

error TranscriptExitLocationInvalid(TEID id);
error TranscriptExitLocationIncorrect(TEID id, LocationID expect, LocationID got);

error PlayerAlreadyRegistered(address player);
error PlayerNotRegistered(address player);
error GameFull();
error GameNotStarted();
error GameInProgress();
error GameComplete();
error ZeroMaxPlayers();
error SenderMustBeMaster();

library Games {

    using Games for Game;
    using Locations for Location;
    using LocationMaps for Map;
    using Links for Link;
    using Transcripts for Transcript;

    /// ---------------------------
    /// @dev modifiers
    modifier hasStarted(Game storage self) {
        if (!self.started) revert GameNotStarted();
        _;
    }
    modifier hasNotStarted(Game storage self) {
        if (self.started) revert GameInProgress();
        _;
    }

    modifier hasCompleted(Game storage self) {
        if (!self.completed) revert GameInProgress();
        _;
    }

    modifier hasNotCompleted(Game storage self) {
        if (self.completed) revert GameComplete();
        _;
    }


    /// ---------------------------
    /// @dev state changing methods

    function _init(Game storage self, uint maxPlayers) internal {

        if (self.players.length != 0 || self.locationTokens.length != 0) {
            revert IsInitialised();
        }

        if (maxPlayers == 0) {
            revert ZeroMaxPlayers();
        }
        self.maxPlayers = maxPlayers;
        self.creator = msg.sender;
        self.master = msg.sender;

        self.players.push();
        // Nope: self.locationTokens.push();
        self.map._init();
    }

    function initialized(Game storage self) internal view returns (bool) {
        if (self.players.length == 0) {
            return false;
        }
        return true;
    }

    /// @dev to enable a map re-load (in the event of error during load for
    /// example) we need a way to reset the map and the locations, whilst
    /// keeping the state the transcript relies on intact.
    function resetMappedLocations(Game storage self) internal {

        for (uint16 i = 0; i < self.locationTokens.length; i++) {
            delete self.tokenLocations[self.locationTokens[i]];
        }
        delete self.locationTokens;

        self.map._reset();
    }

    // ----------------------------
    // Game progression
    //

    function start(Game storage self) internal hasNotStarted(self) {
        self.started = true;
    }

    function complete(Game storage self) internal hasStarted(self) hasNotCompleted(self) {
        self.completed = true;
    }

    function joinGame(Game storage self, address p, bytes calldata profile) internal hasNotCompleted(self) hasNotStarted(self) {

        uint8 i = self.iplayers[p];

        if (i != 0) {
            revert PlayerAlreadyRegistered(p);
        }

        if (self.players.length >= type(uint8).max - 1) {
            revert GameFull();
        }

        // the zero'th player is always invalid. otherwise we would need a + 1 here
        if (self.players.length > self.maxPlayers) {
            revert GameFull();
        }

        i = uint8(self.players.length);
        self.players.push();
        self.players[i].addr = p;
        self.players[i].profile = profile;
        self.iplayers[p] = i;
    }

    function setStartLocation(
        Game storage self, address p, bytes32 startLocation, bytes calldata sceneblob
        ) hasNotStarted(self) internal {

        uint8 i = self.iplayers[p];

        if (i == 0) {
            revert PlayerNotRegistered(p);
        }

        // Can't do this until the locations are loaded
        // self.players[i].loc = self.location(startLocation);

        self.players[i].startLocation = startLocation;
        self.players[i].sceneblob = sceneblob;
    }

    // ----------------------------
    // Game transcript checking

    function load(Game storage self, RawLocation[]calldata raw) internal hasCompleted(self) {
        self.map.load(raw);
    }
    function load(Game storage self, RawExit[]calldata raw) internal hasCompleted(self) {
        self.map.load(raw);
    }
    function load(Game storage self, RawLink[]calldata raw) internal hasCompleted(self) {
        self.map.load(raw);
    }

    /// @dev reveals the mapping from location tokens to location id's in the
    /// fullness of time the tokens will be derived from the block number
    /// corresponding to when the game transcript entry was created. So it will
    /// be many -> 1. Two players getting the same location token for a single
    /// location will mean they entered the location on the same block number.
    function load(Game storage self, TranscriptLocation[]calldata locations) internal hasCompleted(self) {
        for (uint16 i=0; i < locations.length; i++) {

            uint16 iloc = LocationID.unwrap(locations[i].id);

            if (iloc == 0 || iloc >= self.map.locations.length) {
                revert InvalidTranscriptLocation(locations[i].token, iloc);
            }
            self.locationTokens.push(locations[i].token);
            self.tokenLocations[locations[i].token] = LocationID.unwrap(locations[i].id);
        }

        // resolve the player start locations so that the transcripts will work

        for (uint8 i=1; i < self.players.length; i++){
            self.players[i].loc = self.location(self.players[i].startLocation);
        }
    }

    /// @dev plays through the transcript. reverts if any step is invalid. Note
    /// if called with end set to TEID(0) the whole transcript will execute
    /// *provided* there is enough GAS to do so. Use the semi openrange [cur,
    /// end) for processing transcripts in batches. If you mess that up, the
    /// Game will need to be reset befor trying again
    /// @param self the current game state
    /// @param cur the current possition
    /// @param trans the game transcript to evaluate
    function playTranscript(
        Game storage self, Transcript storage trans, TEID cur, TEID _end) internal returns (TEID) {

        uint16 end = TEID.unwrap(_end);
        bool cursorComplete = false;
        TranscriptEntry memory te;

        for(;!cursorComplete && (end == 0 || TEID.unwrap(cur) != end);) {

            (cur, te, cursorComplete) = trans.next(cur);

            Player storage p = player(self, te.player);
            if (p.halted) {
                revert Halted(te.player);
            }

            if (te.kind == Transcripts.MoveKind.ExitUse) {

                ExitUse storage u = trans.exitUse(cur);
                ExitUseOutcome storage o = trans.exitUseOutcome(cur);

                // lookup the location token from the transcript and see if it
                // matches the location id we got by traversing the map exit. If
                // the token lookup fails or if the location we get doesn't
                // match then the transcript or the map are invalid.
                LocationID expected = self.location(o.location);

                // The transcript contains a valid location token for the
                // outcome, go ahead and see if the map and player state agrees.
                self._useExit(p, u.side, u.egressIndex);

                if (LocationID.unwrap(expected) != LocationID.unwrap(p.loc)) {
                    revert TranscriptExitLocationIncorrect(cur, expected, p.loc);
                }

                // Note: if the entry was allowed we always apply it. The halt is applied after the move.
                p.halted = te.halted;
                continue;
            }
        }
        return cur;
    }

    function playTranscript(Game storage self, Transcript storage trans) internal returns (TEID) {
        return self.playTranscript(trans, cursorStart, TEID.wrap(0));
    }

    /// @notice Attempt to move through an exit link. If successful, the player
    /// location is updated to the location on the other side of the link.
    function _useExit(
        Game storage self, Player storage p, Locations.SideKind side, uint8 exitIndex
        ) internal hasCompleted(self) {

        Location storage loc = self.map.location(p.loc);

        ExitID egressVia = loc.exitID(side, exitIndex);

        ExitID ingressVia = self.map.traverse(egressVia);

        p.loc = self.map.locationid(ingressVia);
    }

    /// ---------------------------
    /// @dev state reading methods

    function playerRegistered(Game storage self, address p) internal view returns (bool) {

        uint8 i = self.iplayers[p];
        if (i == 0) {
            return false;
        }

        if (i >= self.players.length) {
            return false;
        }

        return true;
    }

    function player(Game storage self, address _player) internal view returns (Player storage) {
        if (self.iplayers[_player] == 0 || self.iplayers[_player] >= self.players.length) {
            revert InvalidPlayer(_player);
        }
        return self.players[self.iplayers[_player]];
    }

    /// @notice get the number of players currently known to the game (they may not be registered by the host yet)
    /// @param self game storage ref
    /// @return number of known players
    function playerCount(Game storage self) internal view returns (uint8) {
        return uint8(self.players.length - 1); // players[0] is invalid
    }

    /// @notice returns the indext player record from storage
    /// @dev we account for the zeroth invalid player slot automatically
    /// @param self game storage ref
    /// @param _iplayer index of player from the half open range [0 - playerCount())
    /// @return player storage reference
    function player(Game storage self, uint8 _iplayer) internal view returns (Player storage) {
        if (_iplayer >= self.players.length - 1) {
            revert InvalidPlayerIndex(_iplayer);
        }
        return self.players[_iplayer + 1];
    }

    function location(Game storage self, bytes32 token) internal view returns (LocationID) {
        uint16 i = self.tokenLocations[token];
        if (i == 0 || i >= self.map.locations.length) {
            revert InvalidLocationToken(token);
        }
        return LocationID.wrap(i);
    }

    function location(Game storage self, LocationID id) internal view returns (Location storage) {
        return self.map.location(id);
    }

    function exit(Game storage self, ExitID id) internal view returns (Exit storage) {
        return self.map.exit(id);
    }

    function link(Game storage self, LinkID id) internal view returns (Link storage) {
        return self.map.link(id);
    }
}