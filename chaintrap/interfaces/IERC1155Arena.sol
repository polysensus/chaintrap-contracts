// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {TranscriptInitArgs} from "chaintrap/libtranscript.sol";
import {AvatarInitArgs} from "chaintrap/libavatar.sol";

interface IERC1155Arena {
    /// ---------------------------------------------------
    /// @dev game minting and signup
    /// ---------------------------------------------------
    function createAvatar(
        AvatarInitArgs calldata args,
        uint256 avatarType
    ) external returns (uint256);

    function createGame(
        TranscriptInitArgs calldata initArgs
    ) external returns (uint256);

    function lastGame() external view returns (uint256);
}
