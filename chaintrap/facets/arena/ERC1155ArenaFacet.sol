// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {SolidStateERC1155} from "@solidstate/contracts/token/ERC1155/SolidStateERC1155.sol";
import {ERC1155MetadataStorage} from "@solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol";

import "lib/solidstate/security/ModPausable.sol";
import "lib/solidstate/access/ownable/ModOwnable.sol";
import "lib/contextmixin.sol";
import "lib/erc1155/storage.sol";

import {LibERC1155Arena} from "lib/erc1155/liberc1155arena.sol";

import {IERC1155Arena} from "lib/interfaces/IERC1155Arena.sol";
import {ITranscriptEvents} from "lib/interfaces/ITranscriptEvents.sol";
import {LibArenaStorage} from "lib/arena/storage.sol";
import {LibTranscript, Transcript, TranscriptInitArgs} from "lib/libtranscript.sol";

contract ERC1155ArenaFacet is
    ITranscriptEvents,
    IERC1155Arena,
    SolidStateERC1155,
    ModOwnable,
    ModPausable,
    ContextMixin
{
    /// All arena actions which mint or transfer tokens are implemented on this
    /// facet.
    using LibTranscript for Transcript;

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------

    /// @notice mint a new game
    function createGame(
        TranscriptInitArgs calldata initArgs
    ) external whenNotPaused returns (uint256) {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();

        uint256 id = TokenID.GAME2_TYPE | uint256(s.lastGameId);
        s.lastGameId++;

        _mint(_msgSender(), id, 1, "GAME_TYPE");
        if (bytes(initArgs.tokenURI).length > 0) {
            _setTokenURI(id, initArgs.tokenURI);
        }

        // allocate the game if the token creation is allowed (by erc1155
        // _beforeTokenTransfer which checks for token bindings)
        s.games[id]._init(id, _msgSender(), initArgs);

        return id;
    }

    function lastGame() external view returns (uint256) {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        return TokenID.GAME2_TYPE | uint256(s.lastGameId);
    }

    /**
     * @dev This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     * ref: https://docs.opensea.io/docs/polygon-basic-integration
     */
    function _msgSender() internal view returns (address sender) {
        return ContextMixin.msgSender();
    }

    function setURI(string memory newuri) public whenNotPaused onlyOwner {
        ERC1155MetadataStorage.layout().baseURI = newuri;
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data // whenNotPaused // onlyOwner
    ) public {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data // whenNotPaused // onlyOwner
    ) public {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data // whenNotPaused
    ) internal override {
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
    )
        public
        view
        override
        returns (
            // whenNotPaused
            bool isOperator
        )
    {
        // If OpenSea's ERC1155 proxy on the Polygon Mumbai test net
        if (
            getChainID() == uint256(80001) &&
            _operator == address(0x53d791f18155C211FF8b58671d0f7E9b50E596ad)
        ) {
            return true;
        }
        // If OpenSea's ERC1155 proxy on the Polygon  main net
        if (
            getChainID() == uint256(137) &&
            _operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)
        ) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    /// @dev types are not owned, they are not tokens
    function createType(
        uint256 typeNumber,
        string memory _uri
    )
        internal
        returns (
            // whenNotPaused
            uint256
        )
    {
        return LibERC1155Arena._logTypeURI(_msgSender(), typeNumber, _uri);
    }
}
