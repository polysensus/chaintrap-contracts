// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {IERC1155BaseInternal} from "@solidstate/contracts/token/ERC1155/base/IERC1155BaseInternal.sol";
import {ERC1155BaseStorage} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol";

import "lib/erc1155/storage.sol";
import "lib/tokenid.sol";

error TokenNotBoundBy(uint256, uint256);

library LibERC1155Arena {
    event URI(string value, uint256 indexed tokenId);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    ///
    /// @dev minting methods

    /// ---------------------------
    /// @dev token binding methods

    // TODO: emit event for bind/release token
    function findBoundToken(
        uint subject,
        uint holder
    ) internal view returns (uint) {
        return _findBoundToken(ArenaERC1155Storage.layout(), subject, holder);
    }

    function bindToken(uint subject, uint holder) internal {
        _bindToken(ArenaERC1155Storage.layout(), subject, holder);
    }

    function releaseToken(uint subject, uint holder) internal {
        _releaseToken(ArenaERC1155Storage.layout(), subject, holder);
    }

    function _findBoundToken(
        ArenaERC1155Storage.Layout storage self,
        uint subject,
        uint holder
    ) internal view returns (uint) {
        uint[] storage bound = self.boundTokens[holder];

        for (uint i = 0; i < bound.length; i++) {
            if (bound[i] == subject) return i;
        }
        return bound.length;
    }

    function _bindToken(
        ArenaERC1155Storage.Layout storage self,
        uint subject,
        uint holder
    ) internal {
        self.tokenBinding[subject] = holder;
        self.boundTokens[holder].push(subject);
    }

    function _releaseToken(
        ArenaERC1155Storage.Layout storage self,
        uint subject,
        uint holder
    ) internal {
        uint[] storage bound = self.boundTokens[holder];
        uint i = _findBoundToken(self, subject, holder);

        if (i >= bound.length) revert TokenNotBoundBy(subject, holder);

        bound[i] = bound[bound.length - 1];
        bound.pop();
    }

    /// @dev types are not owned, they are not tokens
    function _logTypeURI(
        address msgSender,
        uint256 typeNumber,
        string memory _uri
    ) internal returns (uint256) {
        uint256 ty = (typeNumber) << TokenID.ID_TYPE_SHIFT;

        // emit a Transfer event with Create to help with discovery
        emit TransferSingle(msgSender, address(0x0), address(0x0), ty, 0);
        if (bytes(_uri).length > 0) emit URI(_uri, ty);
        return ty;
    }
}
