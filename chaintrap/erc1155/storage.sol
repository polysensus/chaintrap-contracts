// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "chaintrap/erc1155/liberc1155arena.sol";
import "chaintrap/tokenid.sol";

library ArenaERC1155Storage {
    struct Layout {
        bool initialised;
        /// @dev any token put in this map is bound to a specific owner token. The *can
        /// not* be transfered while bound this way.
        mapping(uint => uint) tokenBinding;
        /// @dev the reverse mapping, the tokens in the array for any token id will
        /// all be found in tokenBinding and will map to the same token id
        mapping(uint => uint[]) boundTokens;
        /// @dev ERC1155 machinery closely following
        /// https://github.com/enjin/erc-1155
        uint256 typeNonce;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("ArenaERC1155.storage.contracts.chaintrap.polysensus");

    function layout()
        internal
        pure
        returns (ArenaERC1155Storage.Layout storage s)
    {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function _idempotentInit(string[] calldata typeURIs) internal {
        ArenaERC1155Storage.Layout storage s = ArenaERC1155Storage.layout();
        if (s.initialised) return;

        s.typeNonce = TokenID.MAX_FIXED_TYPE + 1;

        if (typeURIs.length != 0) {
            for (uint i = 0; i < typeURIs.length; i++) {
                LibERC1155Arena._logTypeURI(msg.sender, i + 1, typeURIs[i]);
            }
        }
        s.initialised = true;
    }
}
