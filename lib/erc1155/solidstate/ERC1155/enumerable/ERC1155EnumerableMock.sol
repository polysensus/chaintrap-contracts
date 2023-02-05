// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import { IERC1155 } from '../IERC1155.sol';
import { ERC1155Base } from '../base/ERC1155Base.sol';
import { ERC1155BaseInternal } from '../base/ERC1155BaseInternal.sol';
import { ERC1155Enumerable } from './ERC1155Enumerable.sol';
import { ERC1155EnumerableInternal } from './ERC1155EnumerableInternal.sol';

contract ERC1155EnumerableMock is ERC1155Enumerable, ERC1155Base {
    constructor() { }

    function __mint(address account, uint256 id, uint256 amount) external {
        _mint(account, id, amount, '');
    }

    function __burn(address account, uint256 id, uint256 amount) external {
        _burn(account, id, amount);
    }

    /**
     * @notice ERC1155 hook: update aggregate values
     * @inheritdoc ERC1155EnumerableInternal
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
        override(ERC1155BaseInternal, ERC1155EnumerableInternal)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
