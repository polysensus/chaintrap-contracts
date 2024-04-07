// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {LibTestDeploy} from "tests/LibTestDeploy.sol";

import {TokenID, maskTypeField} from "chaintrap/tokenid.sol";
import {IERC1155Arena} from "chaintrap/interfaces/IERC1155Arena.sol";
import {AvatarInitArgs} from "chaintrap/libavatar.sol";
import {Arena_setup} from "tests/Arena_setup.sol";

contract Arena_createAvatar is
    Arena_setup {

    function setUp() public {
      setup_deployedArena();
    }

    function test_deployOk() public view {
      assertEq(address(arena) == address(0), false);
      console.log("arena", address(arena));
    }

    function test_createAvatar() public {
      uint256 id = arena.createAvatar(AvatarInitArgs("my/avatar/url"), TokenID.NARRATOR_AVATAR);
      assertEq(maskTypeField(id), TokenID.NARRATOR_AVATAR);
    }
}


