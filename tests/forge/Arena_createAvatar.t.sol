// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {LibTestDeploy} from "tests/LibTestDeploy.sol";

import {TokenID, maskTypeField} from "chaintrap/tokenid.sol";
import {IERC1155Arena} from "chaintrap/interfaces/IERC1155Arena.sol";
import {AvatarInitArgs} from "chaintrap/libavatar.sol";

contract Arena_createAvatar is
    Test {

    address tokenDeployer;
    address operator;

    IERC1155Arena arena;

    function setUp() public {

      tokenDeployer = vm.addr(1);
      operator = vm.addr(10);

      arena = IERC1155Arena(LibTestDeploy.newChaintrapArena(vm, tokenDeployer, operator));
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


