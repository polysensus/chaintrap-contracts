// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/erc1155/erc1155storage.sol";

error TokenNotBoundBy(uint256, uint256);

library LibERC1155Polysensus {

    /// 
    /// @dev minting methods

    /// ---------------------------
    /// @dev token binding methods

    // TODO: emit event for bind/release token
    function findBoundToken(
        uint subject, uint holder
    ) internal view returns (uint) {
        return _findBoundToken(ERC1155PolysensusStorage.layout(), subject, holder);
    }
    function bindToken(
        uint subject, uint holder
    ) internal {
        _bindToken(ERC1155PolysensusStorage.layout(), subject, holder);
    }
    function releaseToken(uint subject, uint holder) internal {
        _releaseToken(ERC1155PolysensusStorage.layout(), subject, holder);
    }

    function _findBoundToken(
        ERC1155PolysensusStorage.Layout storage self, uint subject, uint holder
    ) internal view returns (uint) {
        uint[] storage bound = self.boundTokens[holder];

        for (uint i = 0; i < bound.length; i++){
            if (bound[i] == subject) return i;
        }
        return bound.length;
    }

    function _bindToken(
        ERC1155PolysensusStorage.Layout storage self, uint subject, uint holder) internal {
        self.tokenBinding[subject] = holder;
        self.boundTokens[holder].push(subject);
    }

    function _releaseToken(
        ERC1155PolysensusStorage.Layout storage self, uint subject, uint holder) internal {

        uint[] storage bound = self.boundTokens[holder];
        uint i = _findBoundToken(self, subject, holder);

        if (i >= bound.length) revert TokenNotBoundBy(subject, holder);

        bound[i] = bound[bound.length - 1];
        bound.pop();
    }
}
