// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "lib/tokenid.sol";

library ERC1155PolysensusStorage {

    struct Layout {
        /// @dev any token put in this map is bound to a specific owner token. The *can
        /// not* be transfered while bound this way.
        mapping (uint => uint) tokenBinding;

        /// @dev the reverse mapping, the tokens in the array for any token id will
        /// all be found in tokenBinding and will map to the same token id
        mapping (uint => uint[]) boundTokens;

        /// @dev ERC1155 machinery closely following
        /// https://github.com/enjin/erc-1155
        uint256 typeNonce;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('polysensus.contracts.storage.ERC1155Polysensus');

    function layout() internal pure returns (ERC1155PolysensusStorage.Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
