// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {Test} from "forge-std/Test.sol";
import {LibArenaStorage} from "chaintrap/arena/storage.sol";
import {TokenID, maskTypeField} from "chaintrap/tokenid.sol";
import {LibAvatar, AvatarInitArgs} from "chaintrap/libavatar.sol";
import {ERC1155ArenaFacet} from "chaintrap/facets/arena/ERC1155ArenaFacet.sol";

contract ERC1155ArenaFacet_createAvatar is Test {

  function test_createAvatar_narrator() public {

    LibArenaStorage._idempotentInit();

    // AvatarInitArgs memory args;
    // args.tokenURI = "my/fancy/metadata";

    uint256 id = LibAvatar.newAvatarId(TokenID.NARRATOR_AVATAR);
    assertEq(maskTypeField(id), TokenID.NARRATOR_AVATAR);
  }
}
