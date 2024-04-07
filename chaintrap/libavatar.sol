// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {LibArenaStorage} from "chaintrap/arena/storage.sol";
import {TokenID, InvalidTokenType} from "chaintrap/tokenid.sol";

struct AvatarInitArgs {
    /// @dev nft uri for the game token
    string tokenURI;
}

struct Avatar {
    uint256 x;
}

library LibAvatar {
    using LibAvatar for Avatar;
    using LibArenaStorage for LibArenaStorage.Layout;

    function newAvatarId(uint256 avatarType) internal returns (uint256) {
        if (
            /*avatarType != TokenID.NARRATOR_AVATAR &&*/
            avatarType != TokenID.NARRATOR_AVATAR &&
            avatarType != TokenID.RAIDER_AVATAR
        ) revert InvalidTokenType(avatarType);

        LibArenaStorage.Layout storage s = LibArenaStorage.layout();

        return avatarType | s.nextSeq(avatarType);
    }
}
