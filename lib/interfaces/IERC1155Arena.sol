// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import {TranscriptInitArgs} from "lib/libtranscript.sol";

interface IERC1155Arena {
    /// ---------------------------------------------------
    /// @dev game minting and signup
    /// ---------------------------------------------------

    function createGame(
        TranscriptInitArgs calldata initArgs
    ) external returns (uint256);

    function lastGame() external view returns (uint256);
}
