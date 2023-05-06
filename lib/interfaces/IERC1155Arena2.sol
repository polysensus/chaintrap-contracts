// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import {Game2InitArgs} from "lib/game2.sol";

interface IERC1155Arena2 {
    /// ---------------------------------------------------
    /// @dev game minting functions
    /// ---------------------------------------------------

    function createGame2(
        Game2InitArgs calldata initArgs
    ) external returns (uint256);
}
