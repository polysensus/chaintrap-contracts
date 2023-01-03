// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

import "../lib/game.sol";
import "../lib/contextmixin.sol";

error InvalidGame(uint256 id);

error ArenaError(uint);

/// Games are played in an arena. The arena remembers all games that have ever
/// been played
contract Arena is ERC1155URIStorage, ContextMixin {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;

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

    Transcript[] transcripts;
    Game[] games;

    /// @dev to allow game loading mistakes to be rectified we allow a game to
    /// be discarded. This means there is a many - 1 relationship from  games to
    /// transcripts. The transcript can only be produced once by actual player
    /// interaction. The game state we can re-create at will.
    mapping (GameID => TID) gid2tid;

    /// @dev ERC1155 machinery closely following
    /// https://github.com/enjin/erc-1155
    uint256 typeNonce;
    mapping (uint256 => uint256) typeLast;
    uint256 constant ID_TYPE_BITS = 32;
    uint256 constant ID_TYPE_SHIFT = 256 - ID_TYPE_BITS;
    uint256 constant ID_TYPE_MASK = uint256(uint32(int32(~0))) << ID_TYPE_SHIFT;
    uint256 constant ID_TYPE_NF_BIT = 1 << 255;
    uint256 constant ID_NF_MASK = uint224(int224(~0));

    // No public facing type creation
    uint256 constant GAME_TYPE = (1 << ID_TYPE_SHIFT);
    uint256 constant TRANSCRIPT_TYPE = (2 << ID_TYPE_SHIFT);

    constructor () ERC1155("") {
        // id 0 is always invalid

        transcripts.push();
        transcripts[0]._init(GameID.wrap(0));

        games.push();
        // Don't init games[0]

        createType("", true); // GAME_TYPE
        createType("", true); // TRANSCRIPT_TYPE
    }

    /// ---------------------------------------------------
    /// @dev ERC1155 machinery
    function createType(
        string memory _uri, bool _isNF
    ) internal returns (uint256) {

        uint256 ty = (++typeNonce) << ID_TYPE_SHIFT;
        if (_isNF)
            ty = ty | ID_TYPE_NF_BIT;

        // emit a Transfer event with Create to help with discovery
        emit TransferSingle(_msgSender(), address(0x0), address(0x0), ty, 0);
        if (bytes(_uri).length > 0)
            emit URI(_uri, ty);
        return ty;
    }

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

    /*
    function isNonFungible(uint256 _id) internal pure returns(bool) {
        return _id & ID_TYPE_NF_BIT == ID_TYPE_NF_BIT;
    }
    function isFungible(uint256 _id) internal pure returns(bool) {
        return _id & ID_TYPE_NF_BIT == 0;
    }
    function nfIndex(uint256 _id) public pure returns(uint256) {
        return _id & ID_NF_INDEX_MASK;
    }
    function nfBaseType(uint256 _id) public pure returns(uint256) {
        return _id & ID_TYPE_MASK;
    }
    function isNFBaseType(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does not have an index.
        return (_id & ID_TYPE_NF_BIT == ID_TYPE_NF_BIT) && (_id & ID_NF_MASK == 0);
    }
    function isNFItem(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does has an index.
        return (_id & ID_TYPE_NF_BIT == ID_TYPE_NF_BIT) && (_id & ID_NF_MASK != 0);
    }*/

    /// ---------------------------------------------------

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------

    /// @notice creates a new game context.
    /// @return returns the id for the game
    function createGame(uint maxPlayers, string calldata tokenURI) public returns (GameID) {

        GameID gid = GameID.wrap(games.length);

        games.push();
        Game storage g = games[GameID.unwrap(gid)];
        g._init(maxPlayers, _msgSender());

        TID tid = TID.wrap(transcripts.length);
        transcripts.push();
        transcripts[TID.unwrap(tid)]._init(gid);

        gid2tid[gid] = tid;

        uint256 tokenId = GAME_TYPE | GameID.unwrap(gid);

        _mint(_msgSender(), tokenId, 1, "");

        if (bytes(tokenURI).length > 0) {
            _setURI(tokenId, tokenURI);
        }

        // The trancscript gets minted to the winer when the game is completed and verified
        // _mint(_msgSender(), TRANSCRIPT_TYPE | TID.unwrap(tid), 1, "");

        emit GameCreated(gid, tid, g.creator, g.maxPlayers);
        return gid;
    }

    function lastGame() public view returns (GameID) {
        return GameID.wrap(games.length - 1);
    }

    function gameValid(GameID gid) public view returns (bool) {
        (bool ok, uint256 i) = _index(gid);
        if (!ok) {
            return false;
        }
        return games[i].initialized();
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

    function playerRegistered(GameID gid, address p) public view returns (bool) {
        return game(gid).playerRegistered(p);
    }

    function gameStatus(GameID id) public view returns (GameStatus memory) {
        Game storage g = game(id);
        GameStatus memory gs;
        gs.creator = g.creator;
        gs.master = g.master;
        gs.started = g.started;
        gs.completed = g.completed;

        gs.maxPlayers = g.maxPlayers;
        gs.numRegistered = g.players.length - 1;
        return gs;
    }

    function creator(GameID gid) public view returns (address) {
        return game(gid).creator;
    }

    function master(GameID gid) public view returns (address) {
        return game(gid).master;
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

    /// ---------------------------------------------------
    /// @dev map & game loading.
    /// these methods are only called after the game
    /// is complete(closed)
    /// ---------------------------------------------------

    function loadLocations(GameID gid, RawLocation[] calldata raw) public {
        game(gid).load(raw);
    }

    function loadExits(GameID gid, RawExit[]calldata raw) public {
        return game(gid).load(raw);
    }

    function loadLinks(GameID gid, RawLink[] calldata raw) public {
        game(gid).load(raw);
    }

    function load(GameID gid, RawLocation[] calldata raw) public {
        game(gid).load(raw);
    }
    function load(GameID gid, RawExit[] calldata raw) public {
        game(gid).load(raw);
    }

    function loadTranscriptLocations(GameID gid, TranscriptLocation[]calldata locations) public {
        game(gid).load(locations);
    }

    /// @notice if a mistake is made loading the game map reset it using this
    /// method. The game and transcript ids are unchanged
    function resetMappedLocations(GameID gid) public {

        game(gid).resetMappedLocations();
        emit GameReset(gid, gid2tid[gid]);
    }

    /// ---------------------------------------------------
    /// @dev transcript playback
    /// ---------------------------------------------------

    function playTranscript(GameID gid, TEID cur, TEID end) public returns (TEID) {
        return game(gid).playTranscript(_trans(gid, false), cur, end);
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
