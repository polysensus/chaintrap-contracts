// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

// import "@solidstate/contracts/token/ERC1155/base/ERC1155BaseInternal.sol";
// import "@solidstate/contracts/token/ERC1155/metadata/ERC1155MetadataInternal.sol";

import "lib/solidstate/security/ModPausable.sol";
import "lib/solidstate/access/ownable/ModOwnable.sol";

import { LibERC1155Arena } from "lib/erc1155/liberc1155arena.sol";
import "lib/interfaces/IArenaEvents.sol";
import "lib/contextmixin.sol";
import "lib/tokenid.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "lib/arena/storage.sol";
import "lib/arena/accessors.sol";

error InsufficientBalance(address addr, uint256 id, uint256 balance);

error ArenaError(uint);

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract ArenaFacet is IArenaEvents,
    // ERC1155BaseInternal,
    // ERC1155MetadataInternal,
    ModOwnable,
    ModPausable,
    ContextMixin
    {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

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
        ArenaAccessors.game(gid).joinGame(p, profile);
        emit PlayerJoined(gid, p, profile);
    }

    function setStartLocation(
        GameID gid, address p, bytes32 startLocation, bytes calldata sceneblob
    ) public whenNotPaused {
        (Game storage g, ) = ArenaAccessors._gametrans(gid, false);
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
        ArenaAccessors.game(gid).placeFurniture(placement, id);
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
        (Game storage g, ) = ArenaAccessors._gametrans(gid, false);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.start();
        emit GameStarted(gid);
    }

    function completeGame(GameID gid) public whenNotPaused {
        (Game storage g, ) = ArenaAccessors._gametrans(gid, true);
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
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.reject(id, halt);
    }

    function allowAndHalt(GameID gid, TEID id) public whenNotPaused {
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        t.allowAndHalt(id);
    }

    // --- move specific commit/allow methods

    /// @dev commitExitUse is called by a registered player to commit to using a specific exit.
    function commitExitUse(GameID gid, ExitUse calldata committed)  public whenNotPaused returns (TEID) {
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (!g.playerRegistered(_msgSender())) {
            revert PlayerNotRegistered(_msgSender());
        }
        return t.commitExitUse(_msgSender(), committed);
    }

    /// @dev allowExitUse is called by the game master to declare the outcome of the players commited exit use.
    function allowExitUse(GameID gid, TEID id, ExitUseOutcome calldata outcome) public whenNotPaused {
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowExitUse(id, outcome);
    }


    /// @dev commitFurnitureUse is called by any participant to bind a token to a game session.
    /// The effect of this on the game session is token specific
    function commitFurnitureUse(GameID gid, FurnitureUse calldata committed)  public whenNotPaused returns (TEID) {
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (g.master != _msgSender() && !g.playerRegistered(_msgSender())) {
            revert NotAParticipant(_msgSender());
        }
        return t.commitFurnitureUse(_msgSender(), committed);
    }

    /// @dev allowFurnitureUse is called by the game master to declare the outcome of the participants commited token use.
    /// Note that for placement of map items before the game start, the host can 'self allow'
    function allowFurnitureUse(GameID gid, TEID id, FurnitureUseOutcome calldata outcome) public whenNotPaused {
        (Game storage g, Transcript storage t) = ArenaAccessors._gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowFurnitureUse(id, outcome);
    }
}
