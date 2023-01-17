// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

import "../lib/tokenid.sol";
import "../lib/game.sol";
import "../lib/furnishings.sol";
import "../lib/contextmixin.sol";

error InvalidGame(uint256 id);
error InsufficientBalance(address addr, uint256 id, uint256 balance);

error ArenaError(uint);

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract Arena is ERC1155URIStorage, Ownable, ContextMixin {

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

    Game[] games;
    Transcript[] transcripts;
    Furniture[] furniture;

    /// @dev to allow game loading mistakes to be rectified we allow a game to
    /// be discarded. This means there is a many - 1 relationship from  games to
    /// transcripts. The transcript can only be produced once by actual player
    /// interaction. The game state we can re-create at will.
    mapping (GameID => TID) gid2tid;

    /// @dev any token put in this map is bound to a specific game. The *can
    /// not* be transfered while bound this way.
    mapping (uint256 => uint256) tokenBinding;

    /// @dev the reverse mapping, the tokens in the array for any gameID will
    /// all be found in tokenBinding and will map to the same game.
    mapping (uint256 => uint256[]) boundTokens;

    // XXX: NOTICE It is the callers responsibility to maintain the bindings as
    // a DAG. no checks are made to avoid loops. Depending on how the bindings
    // are used, loops may create un-recoverable situations.

    /// @dev ERC1155 machinery closely following
    /// https://github.com/enjin/erc-1155
    uint256 typeNonce;

    constructor () ERC1155("chaintrap-arena") {
        
        // id 0 is always invalid

        transcripts.push();
        transcripts[0]._init(GameID.wrap(0));

        games.push();
        furniture.push();
        // Don't init xxx [0]

        typeNonce = TokenID.LAST_FIXED_TYPE + 1;

        createFixedType(TokenID.GAME_TYPE, "GAME_TYPE");
        createFixedType(TokenID.TRANSCRIPT_TYPE, "TRANSCRIPT_TYPE");
        createFixedType(TokenID.FURNITURE_TYPE, "FURNITURE_TYPE");
    }

    /// ---------------------------------------------------
    /// @dev ERC1155 machinery

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

/*
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }*/

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        // whenNotPaused
        override
    {
        // XXX: TODO: don't allow transfer of any tokens which are currently bound to open game sessions
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    /*
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }*/

    /**
     * @dev This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     * ref: https://docs.opensea.io/docs/polygon-basic-integration
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }

    /**
     @dev https://ethereum.stackexchange.com/questions/56749/retrieve-chain-id-of-the-executing-chain-from-a-solidity-contract
     */
    function getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
    * Override isApprovedForAll to auto-approve OS's proxy contract
    */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // If OpenSea's ERC1155 proxy on the Polygon Mumbai test net 
        if (getChainID() == uint256(80001) && _operator == address(0x53d791f18155C211FF8b58671d0f7E9b50E596ad)) {
            return true;
        }
        // If OpenSea's ERC1155 proxy on the Polygon  main net
        if (getChainID() == uint256(137) && _operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    /// ---------------------------------------------------

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------

    function createFixedType(
        uint256 typeNumber, string memory _uri

    ) internal returns (uint256) {

        uint256 ty = (typeNumber) << TokenID.ID_TYPE_SHIFT;

        // emit a Transfer event with Create to help with discovery
        emit TransferSingle(_msgSender(), address(0x0), address(0x0), ty, 0);
        if (bytes(_uri).length > 0)
            emit URI(_uri, ty);
        return ty;
    }


    /// @notice creates a new game context.
    /// @return returns the id for the game
    function createGame(uint maxPlayers, string calldata tokenURI) public returns (GameID) {

        uint256 gTokenId = TokenID.GAME_TYPE | uint256(games.length);
        GameID gid = GameID.wrap(games.length);

        games.push();
        Game storage g = games[GameID.unwrap(gid)];
        g._init(maxPlayers, _msgSender(), gTokenId);

        TID tid = TID.wrap(transcripts.length);
        transcripts.push();
        transcripts[TID.unwrap(tid)]._init(gid);

        gid2tid[gid] = tid;

        // XXX: the map owner can set the url later

        // The trancscript gets minted to the winer when the game is completed and verified
        // _mint(_msgSender(), TRANSCRIPT_TYPE | TID.unwrap(tid), 1, "");

        // emit the game state first. we may add mints and their events will
        // force us to update lots of transaction log array values if we put
        // them first.
        emit GameCreated(gid, tid, g.creator, g.maxPlayers);

        // mint the transferable tokens

        // game first, mint to sender
        _mint(_msgSender(), gTokenId, 1, "GAME_TYPE");
        if (bytes(tokenURI).length > 0) {
            _setURI(gTokenId, tokenURI);
        }

        // furniture created as a reward/part of new game - mint to contract owner and hand out depending on victory ?

        // Now the victory condition
        // mint a finish and bind it to the game
        uint256 fTokenId = TokenID.FURNITURE_TYPE | uint128(furniture.length);
        FurnitureID fid  = FurnitureID.wrap(uint128(furniture.length));
        furniture.push();
        furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Finish;
        furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Victory);

        // bind the entrance hall token to the game token
        tokenBinding[fTokenId] = gTokenId;
        boundTokens[gTokenId].push(fTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/finish/victory");

        // Mint two traps to the dungeon creator. We only support insta-death
        fTokenId = TokenID.FURNITURE_TYPE | uint128(furniture.length);
        fid  = FurnitureID.wrap(uint128(furniture.length));
        furniture.push();
        furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        tokenBinding[fTokenId] = gTokenId;
        boundTokens[gTokenId].push(fTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        fTokenId = TokenID.FURNITURE_TYPE | uint128(furniture.length);
        fid  = FurnitureID.wrap(uint128(furniture.length));
        furniture.push();
        furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        tokenBinding[fTokenId] = gTokenId;
        boundTokens[gTokenId].push(fTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        // Now mint a boon

        fTokenId = TokenID.FURNITURE_TYPE | uint128(furniture.length);
        fid  = FurnitureID.wrap(uint128(furniture.length));
        furniture.push();
        furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Boon;
        furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.FreeLife);

        // bind the entrance hall token to the game token
        tokenBinding[fTokenId] = gTokenId;
        boundTokens[gTokenId].push(fTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/boon/free_life");

        return gid;
    }

    function lastGame() public view returns (GameID) {
        return GameID.wrap(games.length - 1);
    }

    function joinGame(GameID gid, bytes calldata profile) public {
        // TODO: consider whether we should allow the master to play their own
        // game. It does alow for pre play testing, and possibly 'single player'
        // creation. Anyone can roll a new wallet and play against themselves,
        // but if we allow master = player then we make it a choice wether self
        // participation as player and master is detectible.
        _joinGame(gid, _msgSender(), profile);
    }

    function _joinGame(GameID gid, address p, bytes calldata profile) public {
        game(gid).joinGame(p, profile);
        emit PlayerJoined(gid, p, profile);
    }

    function setStartLocation(GameID gid, address p, bytes32 startLocation, bytes calldata sceneblob) public {
        (Game storage g, ) = _gametrans(gid, false);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.setStartLocation(p, startLocation, sceneblob);
        emit PlayerStartLocation(gid, p, startLocation, sceneblob);
    }

    function placeFurniture(GameID gid, bytes32 placement, uint256 id) public {

        // check ownership & that it is not already placed.#
        if (balanceOf(_msgSender(), id) == 0) revert InsufficientBalance(_msgSender(), id, 0);
        game(gid).placeFurniture(placement, id);
    }

    function playerRegistered(GameID gid, address p) public view returns (bool) {
        return game(gid).playerRegistered(p);
    }

    function gameStatus(GameID id) public view returns (GameStatus memory) {
        Game storage g = game(id);
        GameStatus memory gs = g.status();
        gs.uri = uri(g.id);
        return gs;
    }

    /// @notice get the number of players currently known to the game (they may not be registered by the host yet)
    /// @param gid game id
    /// @return number of known players
    function playerCount(GameID gid) public view returns (uint8) {
        return game(gid).playerCount();
    }

    /// @notice returns the numbered player record from storage
    /// @dev we account for the zeroth invalid player slot automatically
    /// @param gid gameid
    /// @param _iplayer player number. numbers range over 0 to playerCount() - 1
    /// @return player storage reference
    function player(GameID gid, uint8 _iplayer) public view returns (Player memory) {
        return game(gid).player(_iplayer);
    }

    function player(GameID gid, address _player) public view returns (Player memory) {
        return game(gid).player(_player);
    }

    /// ---------------------------------------------------
    /// @dev game phase transitions
    /// registration - players can join and have their start locations set
    /// started - no more players can join, players can move, game master can confirm
    /// complete - no more moves can take place, transcripts can be checked
    ///
    /// The game starts in the registration phase when it is created.
    /// ---------------------------------------------------

    function startGame(GameID gid) public {
        (Game storage g, ) = _gametrans(gid, false);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        g.start();
        emit GameStarted(gid);
    }

    function completeGame(GameID gid) public {
        (Game storage g, ) = _gametrans(gid, true);
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

    function reject(GameID gid, TEID id) public {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.reject(id);
    }

    function rejectAndHalt(GameID gid, TEID id) public {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.rejectAndHalt(id);
    }

    function allowAndHalt(GameID gid, TEID id) public {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }

        t.allowAndHalt(id);
    }

    // --- move specific commit/allow methods

    /// @dev commitExitUse is called by a registered player to commit to using a specific exit.
    function commitExitUse(GameID gid, ExitUse calldata committed)  public returns (TEID) {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (!g.playerRegistered(_msgSender())) {
            revert PlayerNotRegistered(_msgSender());
        }
        return t.commitExitUse(_msgSender(), committed);
    }

    /// @dev allowExitUse is called by the game master to declare the outcome of the players commited exit use.
    function allowExitUse(GameID gid, TEID id, ExitUseOutcome calldata outcome) public {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowExitUse(id, outcome);
    }


    /// @dev commitFurnitureUse is called by any participant to bind a token to a game session.
    /// The effect of this on the game session is token specific
    function commitFurnitureUse(GameID gid, FurnitureUse calldata committed)  public returns (TEID) {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender() && !g.playerRegistered(_msgSender())) {
            revert NotAParticipant(_msgSender());
        }
        return t.commitFurnitureUse(_msgSender(), committed);
    }

    /// @dev allowFurnitureUse is called by the game master to declare the outcome of the participants commited token use.
    /// Note that for placement of map items before the game start, the host can 'self allow'
    function allowFurnitureUse(GameID gid, TEID id, FurnitureUseOutcome calldata outcome) public {
        (Game storage g, Transcript storage t) = _gametrans(gid, true);
        if (g.master != _msgSender()) {
            revert SenderMustBeMaster();
        }
        t.allowFurnitureUse(id, outcome);
    }


    /// ---------------------------------------------------
    /// @dev map & game loading.
    /// these methods are only called after the game
    /// is complete(closed)
    /// ---------------------------------------------------

    function loadLocations(GameID gid, Location[] calldata locations) public {
        game(gid).load(locations);
    }

    function loadExits(GameID gid, Exit[] calldata exits) public {
        return game(gid).load(exits);
    }

    function loadLinks(GameID gid, Link[] calldata links) public {
        game(gid).load(links);
    }

    function loadTranscriptLocations(GameID gid, TranscriptLocation[]calldata locations) public {
        game(gid).load(locations);
    }

    /// @notice if a mistake is made loading the game map reset it using this
    /// method. The game and transcript ids are unchanged
    function reset(GameID gid) public {

        game(gid).reset();
        emit GameReset(gid, gid2tid[gid]);
    }

    /// ---------------------------------------------------
    /// @dev transcript playback
    /// ---------------------------------------------------

    function playTranscript(GameID gid, TEID cur, TEID end) public returns (TEID) {
        return game(gid).playTranscript(_trans(gid, false), furniture, cur, end);
    }


    /// ---------------------------------------------------
    /// @dev utilities and accessors
    /// ---------------------------------------------------

    /// @dev the only 
    function _index(GameID id) internal view returns (bool, uint256) {

        // The length of games & trans are only changed by createGame
        // so we do not repeat the length consistency checks here.
        if (games.length == 0) {
            return (false, 0);
        }

        uint256 i = GameID.unwrap(id);
        if (i == 0) {
            return (false, 0);
        }
        if (i >= games.length) {
            return (false, 0);
        }
        return (true, i);
    }

    function _trans(GameID gid, bool requireOpen) internal view returns (Transcript storage) {
        (, Transcript storage t) = _gametrans(gid, requireOpen);
        return t;
    }

    function _gametrans(GameID gid, bool requireOpen) internal view returns (Game storage, Transcript storage) {
        (bool ok, uint256 ig) = _index(gid);
        if (!ok) {
            revert InvalidGame(ig);
        }

        TID tid = gid2tid[gid];
        uint256 it = TID.unwrap(tid);

        if (it == 0 || it >= transcripts.length) {
            revert InvalidTID(it);
        }

        if (requireOpen) {
            if (!games[ig].started) {
                revert GameNotStarted();
            }
            if (games[ig].completed) {
                revert GameComplete();
            }
        }

        return (games[ig], transcripts[it]);
    }

    function game(GameID id) internal view returns (Game storage) {

        (bool ok, uint256 i) = _index(id);
        if (!ok) {
            revert InvalidGame(i);
        }
        return games[i];
    }
}
