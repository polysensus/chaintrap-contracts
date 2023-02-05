// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import { ERC1155Metadata, ERC1155MetadataStorage } from './ERC1155Metadata.sol';

contract ERC1155MetadataMock is ERC1155Metadata {
    constructor(string memory baseURI) {
        ERC1155MetadataStorage.layout().baseURI = baseURI;
    }
}
