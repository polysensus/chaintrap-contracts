// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import { SolidStateERC1155 } from "@solidstate/contracts/token/ERC1155/SolidStateERC1155.sol";
import { ERC1155MetadataStorage } from "@solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol";

import "lib/solidstate/security/ModPausable.sol";
import "lib/solidstate/access/ownable/ModOwnable.sol";
import "lib/contextmixin.sol";
import "lib/erc1155/storage.sol";

import { IArenaEvents} from "lib/interfaces/IArenaEvents.sol";
import { LibERC1155Arena } from "lib/erc1155/liberc1155arena.sol";
import { ArenaStorage } from "lib/arena/storage.sol";
import "lib/game.sol";

import "lib/interfaces/IERC1155Arena.sol";

contract ERC1155ArenaFacet is IArenaEvents, IERC1155Arena,
    SolidStateERC1155,
    ModOwnable,
    ModPausable,
    ContextMixin {

    /// All arena actions which mint or transfer tokens are implemented on this
    /// facet.
    using Transcripts for Transcript;
    using Games for Game;

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------
    /// @notice creates a new game context.
    /// @return returns the id for the game
    function createGame(
        uint maxPlayers, string calldata tokenURI
    ) public whenNotPaused returns (GameID) {

        ArenaStorage.Layout storage s = ArenaStorage.layout();

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
        LibERC1155Arena.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/finish/victory");

        // Mint two traps to the dungeon creator. We only support insta-death
        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        LibERC1155Arena.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Trap;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.Death);

        // bind the entrance hall token to the game token
        LibERC1155Arena.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/trap/death");

        // Now mint a boon

        fTokenId = TokenID.FURNITURE_TYPE | uint128(s.furniture.length);
        fid  = FurnitureID.wrap(uint128(s.furniture.length));
        s.furniture.push();
        s.furniture[FurnitureID.unwrap(fid)].kind = Furnishings.Kind.Boon;
        s.furniture[FurnitureID.unwrap(fid)].effects.push(Furnishings.Effect.FreeLife);

        // bind the entrance hall token to the game token
        LibERC1155Arena.bindToken(fTokenId, gTokenId);

        _mint(_msgSender(), fTokenId, 1, "furniture/boon/free_life");

        return gid;
    }


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

    function setURI(string memory newuri)
        public
        whenNotPaused
        onlyOwner 
    {
        ERC1155MetadataStorage.layout().baseURI = newuri;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        // whenNotPaused
        // onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        // whenNotPaused
        // onlyOwner
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
    ) public
        // whenNotPaused
        override
        view returns (bool isOperator) {
        // If OpenSea's ERC1155 proxy on the Polygon Mumbai test net 
        if (getChainID() == uint256(80001) && _operator == address(0x53d791f18155C211FF8b58671d0f7E9b50E596ad)) {
            return true;
        }
        // If OpenSea's ERC1155 proxy on the Polygon  main net
        if (getChainID() == uint256(137) && _operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    /// @dev types are not owned, they are not tokens
    function createType(
        uint256 typeNumber, string memory _uri
    ) internal
        // whenNotPaused
        returns (uint256) {
        return LibERC1155Arena._logTypeURI(_msgSender(), typeNumber, _uri);
    }
}
