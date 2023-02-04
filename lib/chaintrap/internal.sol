// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import "@solidstate/contracts/security/PausableInternal.sol";
import "@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol";
import "@solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol";
import { ERC1155PolysensusInternal } from "lib/erc1155/erc1155internal.sol";
import { LibERC1155Polysensus } from "lib/erc1155/erc1155lib.sol";
import "lib/contextmixin.sol";
import "lib/tokenid.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "./storage.sol";
import "./libaccessors.sol";

error InsufficientBalance(address addr, uint256 id, uint256 balance);

error ArenaError(uint);

abstract contract ArenaViewInternal {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    function lastGame() public view returns (GameID) {
        return GameID.wrap(ChaintrapStorage.layout().games.length - 1);
    }

    function playerRegistered(GameID gid, address p) public view returns (bool) {
        return LibAccessors.game(gid).playerRegistered(p);
    }

    function gameStatus(GameID id) public view returns (GameStatus memory) {
        Game storage g = LibAccessors.game(id);
        GameStatus memory gs = g.status();
        // XXX gs.uri = uri(g.id);
        return gs;
    }

    /// @notice get the number of players currently known to the game (they may not be registered by the host yet)
    /// @param gid game id
    /// @return number of known players
    function playerCount(GameID gid) public view returns (uint8) {
        return LibAccessors.game(gid).playerCount();
    }

    /// @notice returns the numbered player record from storage
    /// @dev we account for the zeroth invalid player slot automatically
    /// @param gid gameid
    /// @param _iplayer player number. numbers range over 0 to playerCount() - 1
    /// @return player storage reference
    function player(GameID gid, uint8 _iplayer) public view returns (Player memory) {
        return LibAccessors.game(gid).player(_iplayer);
    }

    function player(GameID gid, address _player) public view returns (Player memory) {
        return LibAccessors.game(gid).player(_player);
    }
}

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
abstract contract ArenaInternal is
    ERC1155BaseInternal,
    ERC1155MetadataInternal,
    OwnableInternal,
    PausableInternal,
    ContextMixin
    {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    event GameCreated(GameID indexed gid, TID tid, address indexed creator, uint256 maxPlayers);
    event GameReset(GameID indexed gid, TID tid);
    event GameStarted(GameID indexed gid);
    event GameCompleted(GameID indexed gid);
    event PlayerJoined(GameID indexed gid, address player, bytes profile);
    event PlayerStartLocation(GameID indexed gid, address player, bytes32 startLocation, bytes sceneblob);

    // NOTE: These are duplicated in library Transcript - this is the only way to expose the abi to ethers.js
    event UseExit(GameID indexed gid, TEID eid, address indexed player, ExitUse exitUse); // player is the committer of the tx
    event ExitUsed(GameID indexed gid, TEID eid, address indexed player, ExitUseOutcome outcome);
    event EntryReject(GameID indexed gid, TEID eid, address indexed player, bool halted);

    event UseToken(GameID indexed gid, TEID eid, address indexed participant, FurnitureUse use);
    event FurnitureUsed(GameID indexed gid, TEID eid, address indexed participant, FurnitureUseOutcome outcome);

    // The following events are emitted by transcript playback to reveal the full narative of the game
    event TranscriptPlayerEnteredLocation(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed entered, ExitID enteredVia, LocationID left, ExitID leftVia
        );

    event TranscriptPlayerKilledByTrap(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerDied(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerGainedLife(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed location, uint256 furniture
    );

    // only when player.lives > 0
    event TranscriptPlayerLostLife(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed location, uint256 furniture
    );

    event TranscriptPlayerVictory(
        uint256 indexed gameId, TEID eid, address indexed player,
        LocationID indexed location, uint256 furniture
    );

    constructor () { }

    /// ---------------------------------------------------
    /**
     * @dev This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     * ref: https://docs.opensea.io/docs/polygon-basic-integration
     */
    function _msgSender()
        internal
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------


    /// @notice creates a new game context.
    /// @return returns the id for the game
    function createGame(
        uint maxPlayers, string calldata tokenURI
    ) public whenNotPaused returns (GameID) {

        ChaintrapStorage.Layout storage s = ChaintrapStorage.layout();

        uint256 gTokenId = TokenID.GAME_TYPE | uint256(s.games.length);
        GameID gid = GameID.wrap(s.games.length);

        s.games.push();
        Game storage g = s.games[GameID.unwrap(gid)];
        g._init(maxPlayers, _msgSender(), gTokenId);

        TID tid = TID.wrap(s.transcripts.length);
        s.transcripts.push();
        s.transcripts[TID.unwrap(tid)]._init(gid);

        s.gid2tid[gid] = tid;

        // XXX: the map owner can set the url later

        // The trancscript gets minted to the winer when the game is completed and verified
        _mint(_msgSender(), TokenID.TRANSCRIPT_TYPE | TID.unwrap(tid), 1, "");

        // emit the game state first. we may add mints and their events will
        // force us to update lots of transaction log array values if we put
        // them first.
        emit GameCreated(gid, tid, g.creator, g.maxPlayers);

        // mint the transferable tokens

        // game first, mint to sender
        _mint(_msgSender(), gTokenId, 1, "GAME_TYPE");
        if (bytes(tokenURI).length > 0) {
            _setTokenURI(gTokenId, tokenURI);
        }

        // furniture created as a reward/part of new game - mint to contract owner and hand out depending on victory ?

        // Now the victory condition
        // mint a finish and bind it to the game
        uint256 fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        FurnitureID fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Finish;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Victory);

        // bind the entrance hall token to the game token
        LibERC1155Polysensus.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/finish/victory");

        // Mint two traps to the dungeon creator. We only support insta-death
        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        LibERC1155Polysensus.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        LibERC1155Polysensus.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        // Now mint a boon

        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Boon;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.FreeLife);

        // bind the entrance hall token to the game token
        LibERC1155Polysensus.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/boon/free_life");

        return gid;
    }

    function joinGame(
        GameID gid, bytes calldata profile
    ) public {
        // TODO: consider whether we should allow the master to play their own
        // game. It does alow for pre play testing, and possibly 'single player'
        // creation. Anyone can roll a new wallet and play against themselves,
        // but if we allow master = player then we make it a choice wether self
        // participation as player and master is detectible.
        _joinGame(gid, _msgSender(), profile);
    }

    function _joinGame(
        GameID gid, address p, bytes calldata profile
    ) public whenNotPaused {
        LibAccessors.game(gid).joinGame(p, profile);
        emit PlayerJoined(gid, p, profile);
    }

    function setStartLocation(
        GameID gid, address p, bytes32 startLocation, bytes calldata sceneblob
    ) public whenNotPaused {
        (Game storage g, ) = LibAccessors._gametrans(gid, false);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.setStartLocation(p, startLocation, sceneblob);
        emit PlayerStartLocation(gid, p, startLocation, sceneblob);
    }

    function placeFurniture(
        GameID gid, bytes32 placement, uint256 id) public whenNotPaused {

        // check ownership & that it is not already placed.#
        // TODO: XXX if (balanceOf(_msgSender(), id) == 0) revert InsufficientBalance(_msgSender(), id, 0);
        LibAccessors.game(gid).placeFurniture(placement, id);
    }


    /// ---------------------------------------------------
    /// @dev game phase transitions
    /// registration - players can join and have their start locations set
    /// started - no more players can join, players can move, game master can confirm
    /// complete - no more moves can take place, transcripts can be checked
    ///
    /// The game starts in the registration phase when it is created.
    /// ---------------------------------------------------

    function startGame(GameID gid) public whenNotPaused {
        (Game storage g, ) = LibAccessors._gametrans(gid, false);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.start();
        emit GameStarted(gid);
    }

    function completeGame(GameID gid) public whenNotPaused {
        (Game storage g, ) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.complete();
        emit GameCompleted(gid);
    }

    /// ---------------------------------------------------
    /// @dev game progression
    /// The player commits to a move. Then the games master reveals the result.
    /// A transcript is recorded. When the game is declared over by the games
    /// master, the transcripts are checked before any prizes are handed out.
    /// The games master provides vrf proofs for intial random state and map
    /// generation.
    /// ---------------------------------------------------

    function reject(GameID gid, TEID id, bool halt) public whenNotPaused {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.reject(id, halt);
    }

    function allowAndHalt(GameID gid, TEID id) public whenNotPaused {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        t.allowAndHalt(id);
    }

    // --- move specific commit/allow methods

    /// @dev commitExitUse is called by a registered player to commit to using a specific exit.
    function commitExitUse(GameID gid, ExitUse calldata committed)  public whenNotPaused returns (TEID) {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (!g.playerRegistered(_msgSender())) {
            revert PlayerNotRegistered(_msgSender());
        }
        return t.commitExitUse(_msgSender(), committed);
    }

    /// @dev allowExitUse is called by the game master to declare the outcome of the players commited exit use.
    function allowExitUse(GameID gid, TEID id, ExitUseOutcome calldata outcome) public whenNotPaused {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowExitUse(id, outcome);
    }


    /// @dev commitFurnitureUse is called by any participant to bind a token to a game session.
    /// The effect of this on the game session is token specific
    function commitFurnitureUse(GameID gid, FurnitureUse calldata committed)  public whenNotPaused returns (TEID) {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender() && !g.playerRegistered(_msgSender())) {
            revert NotAParticipant(_msgSender());
        }
        return t.commitFurnitureUse(_msgSender(), committed);
    }

    /// @dev allowFurnitureUse is called by the game master to declare the outcome of the participants commited token use.
    /// Note that for placement of map items before the game start, the host can 'self allow'
    function allowFurnitureUse(GameID gid, TEID id, FurnitureUseOutcome calldata outcome) public whenNotPaused {
        (Game storage g, Transcript storage t) = LibAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowFurnitureUse(id, outcome);
    }
}
