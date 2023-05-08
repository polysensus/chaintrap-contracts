// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import {TranscriptInitArgs} from "lib/libtranscript2.sol";

interface IERC1155Arena2 {
    /// ---------------------------------------------------
    /// @dev game minting and signup
    /// ---------------------------------------------------

    function createGame2(
        TranscriptInitArgs calldata initArgs
    ) external returns (uint256);
}
