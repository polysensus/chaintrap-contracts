// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/game.sol";

interface IERC1155Arena {
    /// ---------------------------------------------------
    /// @dev game minting functions
    /// ---------------------------------------------------

    function createGame(
        GameInitArgs calldata initArgs
    ) external returns (GameID);
}
