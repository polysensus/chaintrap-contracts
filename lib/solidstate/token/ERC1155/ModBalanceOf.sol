// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC1155BaseInternal} from "@solidstate/contracts/token/ERC1155/base/IERC1155BaseInternal.sol";
import {ERC1155BaseStorage} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol";

error ModBalanceOf__BalanceQueryZeroAddress();
error ModBalanceOf__NotTokenHolder();

abstract contract ModBalanceOf {
    modifier holdsToken(address account, uint256 id) {
        if (_balanceOf(account, id) == 0) revert ModBalanceOf__NotTokenHolder();
        _;
    }

    /// @dev solidstate's _balanceOf is frustratingly on an abstract contract,
    /// so not accessible via library calls on other facets.
    /**
     * @notice query the balance of given token held by given address
     * @param account address to query
     * @param id token to query
     * @return token balance
     */
    function _balanceOf(
        address account,
        uint256 id
    ) internal view returns (uint256) {
        if (account == address(0))
            revert ModBalanceOf__BalanceQueryZeroAddress();
        return ERC1155BaseStorage.layout().balances[id][account];
    }
}
