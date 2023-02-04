// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "@solidstate/contracts/token/ERC1155/SolidStateERC1155.sol";
import { ERC1155MetadataStorage } from "@solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol";
import "@solidstate/contracts/access/ownable/OwnableInternal.sol";
import "@solidstate/contracts/security/PausableInternal.sol";
import "lib/contextmixin.sol";
import "lib/erc1155/erc1155storage.sol";
import "lib/tokenid.sol";

abstract contract ERC1155PolysensusInternal is
    SolidStateERC1155,
    OwnableInternal,
    PausableInternal,
    ContextMixin {

    function _init(string[] calldata fixedTokenURIs) public onlyOwner {
        // id 0 is always invalid

        ERC1155PolysensusStorage.Layout storage s = ERC1155PolysensusStorage.layout();
        if (s.typeNonce != 0) return;

        for (uint i=0; i < fixedTokenURIs.length; i++) {
            createType(i+1, fixedTokenURIs[i]);
        }

        s.typeNonce = fixedTokenURIs.length + 1;
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
        whenNotPaused
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        whenNotPaused
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
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
        whenNotPaused
        override view returns (bool isOperator) {
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
        whenNotPaused
        returns (uint256) {
        uint256 ty = (typeNumber) << TokenID.ID_TYPE_SHIFT;

        // emit a Transfer event with Create to help with discovery
        emit TransferSingle(_msgSender(), address(0x0), address(0x0), ty, 0);
        if (bytes(_uri).length > 0)
            emit URI(_uri, ty);
        return ty;
    }
}
