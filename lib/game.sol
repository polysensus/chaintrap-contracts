// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "./tokenid.sol";
import "./transcript.sol";
import "./mapstructure.sol";
import "./furnishings.sol";
import "./gameid.sol";

/// @dev Invalid* errors are raised for ids can't be mapped to their respective items.
error InvalidPlayer(address player);
error InvalidPlayerIndex(uint8 player);
error InvalidLocationToken(bytes32 token);
error InvalidTranscriptLocation(bytes32 token, uint16 location);

error TranscriptExitLocationInvalid(TEID id);
error TranscriptExitLocationIncorrect(TEID id, LocationID expect, LocationID got);
error TranscriptPlacementInvalid(bytes32 have, bytes32 stateDerived);
error TranscriptPlacementNotFound(TEID id, bytes32 placement);
error TranscriptPlacementSaltNotFound(TEID id, bytes32 placement);
error TranscriptFurnitureOutcomeKindInvalid(TEID id, uint256 furniture, Furnishings.Kind kind);
error TranscriptFurnitureOutcomeEffectInvalid(TEID id, uint256 furniture, Furnishings.Effect effect);
error TranscriptFurnitureOutcomePlayerShouldHaveHalted(TEID id);
error TranscriptFurnitureOutcomePlayerShouldNotHaveHalted(TEID id);
error TranscriptFurnitureShouldHaveHalted(TEID id, uint256 furniture, Furnishings.Kind kind, Furnishings.Effect effect);
error TranscriptFurnitureShouldNotHaveHalted(TEID id, uint256 furniture, Furnishings.Kind kind, Furnishings.Effect effect);
error TranscriptFurnitureUnknownEffect(TEID id, uint256 furniture, Furnishings.Kind kind, Furnishings.Effect effect);

error PlayerAlreadyRegistered(address player);
error PlayerNotRegistered(address player);

// A participant includes the game master and all players.
error NotAParticipant(address participant);
error GameFull();
error GameNotStarted();
error GameInProgress();
error GameComplete();
error ZeroMaxPlayers();
error SenderMustBeMaster();
error FurnitureTokenRequired(uint256 actualID);

error AssociatedArraysLenghtMismatch(uint256 have, uint256 expect);


struct Player {
    address addr;
    /// LocationID Current location of the player
    LocationID loc;
    bytes32 startLocation;
    bytes sceneblob;
    /// player profile data, opaque to the contract
    bytes profile;
    bool halted;
    uint8 lives; // The count of deaths the player can survive, 0 is the default
}

struct Game {

    /// @dev The following state supports ERC 1155 tokenization and general ownership and authority
    uint256 id;

    /// The creator of the game gets a payout provide the game is completed by
    /// at least one player.
    address creator;

    /// The 'dungeon' master (often the creator) reveals the result of each player move.
    address master;

    /// @dev the following state controls the overal status of the game

    /// maximum number of players
    uint maxPlayers;
    bool started;
    bool completed;

    Player[] players;
    mapping(address => uint8) iplayers;

    // The game transcript locations are tokens. The preimages for which are
    // required to check the transcript
    bytes32[] locationTokens;
    mapping (bytes32 => uint16) tokenLocations;

    // placedTokens include:
    // * furniture - tokens that can only be placed by the game minter (dungeon
    // owner), in a specific room in a specific game. placedTokens will
    // correspond to things in the dungeon which may be *used* by a player and
    // will have an *effect*. These tokens are H(furnitureID, locationID, salt)
    // The game creator can only load the tokens if they have posession of the
    // corresponding furniture items and if the locationID's are valid for the
    // map
    // the following are for future:
    // * encounters - npc encounters, monsters. H(npcID, locationID, salt)
    // * collectibles - tokens that may be dropped by players or monsters or placed in furniture by the game minter
    bytes32[] placedTokens;
    mapping (bytes32 => uint256) placements;

    // These must be loaded after the game completes in order to successfully
    // validate the transcript
    mapping (bytes32 => bytes32) placementSalts;

    // The following state is recorded on the game after it is completed in
    // order to reconcile the state and apply outcomes to participant accounts.
    // participants include both the registered player accounts and the game
    // master. The creator will only be involved if it is also the master or if
    // we are doing things with royalties.
    Map map;
}

struct GameStatus {
    /// The creator of the game gets a payout provide the game is completed by
    /// at least one player.
    address creator;

    /// The 'dungeon' master (often the creator) reveals the result of each player move.
    address master;

    string uri;
    /// maximum number of players
    uint maxPlayers;
    uint numRegistered;
    bool started;
    bool completed;
}

library Games {

    using Games for Game;
    using Locations for Location;
    using LocationMaps for Map;
    using Links for Link;
    using Transcripts for Transcript;
    using Furnishings for Furniture;

    /// @dev these are duplicated in the arena contract due to limitations of solidity
    event TranscriptPlayerEnteredLocation(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed entered, ExitID enteredVia, LocationID left, ExitID leftVia
        );

    event TranscriptPlayerKilledByTrap(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerDied(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerGainedLife(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed location, uint256 furniture
    );

    // only when player.lives > 0
    event TranscriptPlayerLostLife(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerVictory(
        uint256 indexed gameId, TEID eid, address indexed player, LocationID indexed location, uint256 furniture
    );

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

    function _init(Game storage self, uint maxPlayers, address _msgSender, uint256 id) internal {

        if (self.players.length != 0 || self.locationTokens.length != 0 || self.placedTokens.length != 0) {
            revert IsInitialised();
        }

        if (maxPlayers == 0) {
            revert ZeroMaxPlayers();
        }
        self.id = id;
        self.maxPlayers = maxPlayers;
        self.creator = _msgSender;
        self.master = _msgSender;

        self.players.push();
        self.map._init();
        // Nope: self.locationTokens.push();
        // Nope: self.placedTokens.push();
    }

    function initialized(Game storage self) internal view returns (bool) {
        if (self.players.length == 0) {
            return false;
        }
        return true;
    }

    /// @dev to enable a re-load (in the event of error during load for example)
    /// we need a way to reset the map the locations, furnishings etc, whilst
    /// keeping the state the transcript relies on intact.
    function reset(Game storage self) internal {

        for (uint16 i = 0; i < self.locationTokens.length; i++) {
            delete self.tokenLocations[self.locationTokens[i]];
        }
        delete self.locationTokens;

        for (uint16 i = 0; i < self.placedTokens.length; i++) {
            delete self.placements[self.placedTokens[i]];
        }

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

    /// @notice commit the placement of furniture to a particular game
    // The placement is H(locationid, furnitureid, salt). The transcript
    // outcome of using the furniture can not be applied, and hence the game
    // validity is voided, unless the pre-image matching this placement has
    // been loaded when the transcript is checked.
    // This call reveals the presence of the token in the game *before* the
    // game starts. This is _desired_, players can see the general
    // availability of finish conditions, traps and bonuses but can not
    // determine where on the map they are placed.
    /// @param self the game
    /// @param placement KECCAK256(abi.encode(furnitureid, locationid, salt)). NOTICE
    ///                  that we use abi.encode to avoid hash colisions. each
    ///                  field in the hash is 32 bytes always
    /// @param furnitureId furniture nft id, sender must be the owner, must be FURNITURE_TYPE
    function placeFurniture(
        Game storage self, bytes32 placement, uint256 furnitureId
    ) hasNotStarted(self) internal {
        requireType(furnitureId, TokenID.FURNITURE_TYPE);
        self.placedTokens.push(placement);
        self.placements[placement] = furnitureId;
    }

    function placeFurnitureBatch(
        Game storage self, bytes32[] calldata placement, uint256[] calldata furnitureId
    ) public {
        if (placement.length != furnitureId.length)
            revert AssociatedArraysLenghtMismatch(placement.length, furnitureId.length);
        for (uint i = 0; i < placement.length; i ++) {
            placeFurniture(self, placement[i], furnitureId[i]);
        }
    }

    // ----------------------------
    // Game transcript checking

    /// @notice reveal the salt for a placement
    /// @dev revealing the salt is sufficient to allow the placements to be
    /// trivialy brute forced, legitimate game clients will have access to the
    /// pre-image, but once the salt is on chain the location ids and furniture
    /// ids form a very predictable search space.
    /// @param self the game instance
    /// @param placement the tokenised furniture placement
    /// @param salt the salt component of the placement pre-image
    function placementReveal(Game storage self, bytes32 placement, bytes32 salt) internal hasCompleted(self) {
        self.placementSalts[placement] = salt;
    }

    function load(Game storage self, Location[]calldata locations) internal hasCompleted(self) {
        self.map.load(locations);
    }
    function load(Game storage self, Exit[]calldata exits) internal hasCompleted(self) {
        self.map.load(exits);
    }
    function load(Game storage self, Link[]calldata links) internal hasCompleted(self) {
        self.map.load(links);
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
        Game storage self, Transcript storage trans, Furniture[] storage furniture, TEID cur, TEID _end
        ) internal returns (TEID) {

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

                self.useExit(cur, trans, te);
                p.halted = te.halted;
                continue;
            }

            if (te.kind == Transcripts.MoveKind.FurnitureUse) {
                self.useFurniture(cur, trans, te, furniture);
                p.halted = te.halted;
                continue;
            }
        }
        return cur;
    }

    function playTranscript(
        Game storage self, Transcript storage trans, Furniture[] storage furniture
        ) internal returns (TEID) {
        return self.playTranscript(trans, furniture, cursorStart, TEID.wrap(0));
    }

    /// @notice Attempt to move through an exit link. If successful, the player
    /// location is updated to the location on the other side of the link.
    function useExit(
        Game storage self, TEID cur, Transcript storage trans, TranscriptEntry memory te
        ) internal hasCompleted(self) {

        Player storage p = player(self, te.player);
        ExitUse storage u = trans.exitUse(cur);
        ExitUseOutcome storage o = trans.exitUseOutcome(cur);

        // lookup the location token from the transcript and see if it
        // matches the location id we got by traversing the map exit. If
        // the token lookup fails or if the location we get doesn't
        // match then the transcript or the map are invalid.
        LocationID expected = self.location(o.location);

        Location storage loc = self.map.location(p.loc);

        ExitID egressVia = loc.exitID(u.side, u.egressIndex);
        ExitID ingressVia = self.map.traverse(egressVia);

        LocationID from = p.loc;
        p.loc = self.map.locationid(ingressVia);

        if (LocationID.unwrap(expected) != LocationID.unwrap(p.loc)) {
            revert TranscriptExitLocationIncorrect(cur, expected, p.loc);
        }

        emit TranscriptPlayerEnteredLocation(self.id, cur, p.addr, p.loc, egressVia, from, ingressVia);
    }

    function useFurniture(
        Game storage self, TEID cur, Transcript storage trans, TranscriptEntry memory te,
        Furniture[] storage furniture
    ) internal hasCompleted(self) {

        Player storage p = player(self, te.player);
        FurnitureUse storage u = trans.furnitureUse(cur);
        FurnitureUseOutcome storage o = trans.furnitureUseOutcome(cur);

        // The host of the map has two oposing interests here:
        // a) The host is benifited when penalties (traps) fire.
        // b) The host is penalised when bonuses fire.
        //
        // The use is recorded by the player.
        // The outcome is recorded by the host.

        // resolve the token and verify its effect
        uint256 id = self.placements[u.token];
        if (id == 0) revert TranscriptPlacementNotFound(cur, u.token);
        requireType(id, TokenID.FURNITURE_TYPE);

        bytes32 b = self.placementSalts[u.token];
        if (b == 0) revert TranscriptPlacementSaltNotFound(cur, u.token);

        b = keccak256(abi.encode(id, p.loc, b));
        if (b != u.token) revert TranscriptPlacementInvalid(u.token, b);

        Furniture storage f = furniture[nftInstance(id)];

        if (f.kind != o.kind) revert TranscriptFurnitureOutcomeKindInvalid(cur, id, o.kind);

        // Check the outcome against the actual furniture
        bool effectOk = false;
        for (uint i = 0; i < f.effects.length; i++) {
            if (f.effects[i] == o.effect) {
                effectOk = true;
                break;
            }
        }
        if (!effectOk) revert TranscriptFurnitureOutcomeEffectInvalid(cur, id, o.effect);

        if(o.effect == Furnishings.Effect.Victory) {
            if (!te.halted) revert TranscriptFurnitureShouldHaveHalted(cur, id, o.kind, o.effect);
            emit TranscriptPlayerVictory(self.id, cur, p.addr, p.loc, id);
        }
        if(o.effect == Furnishings.Effect.Death) {
            if (p.lives > 0) {
                p.lives -= 1;
                if (te.halted) revert TranscriptFurnitureShouldNotHaveHalted(cur, id, o.kind, o.effect);
                emit TranscriptPlayerLostLife(self.id, cur, p.addr, p.loc, id);
            } else {
                if (!te.halted) revert TranscriptFurnitureShouldHaveHalted(cur, id, o.kind, o.effect);
                if(o.kind == Furnishings.Kind.Trap)
                    emit TranscriptPlayerKilledByTrap(self.id, cur, p.addr, p.loc, id);
                else
                    emit TranscriptPlayerDied(self.id, cur, p.addr, p.loc, id);
            }
        }

        if (o.effect == Furnishings.Effect.FreeLife) {
            p.lives += 1;
            emit TranscriptPlayerGainedLife(self.id, cur, p.addr, p.loc, id);
            return;
        }
        revert TranscriptFurnitureUnknownEffect(cur, id, o.kind, o.effect);
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

    function location(Game storage self, bytes32 tok) internal view returns (LocationID) {
        uint16 i = self.tokenLocations[tok];
        if (i == 0 || i >= self.map.locations.length) {
            revert InvalidLocationToken(tok);
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