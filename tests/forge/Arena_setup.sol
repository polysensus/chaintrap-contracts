// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {LibTestDeploy} from "tests/LibTestDeploy.sol";

import {TokenID, maskTypeField} from "chaintrap/tokenid.sol";
import {IERC1155Arena} from "chaintrap/interfaces/IERC1155Arena.sol";
import {AvatarInitArgs} from "chaintrap/libavatar.sol";

contract Arena_setup is Test {

   address tokenDeployer;
   address operator;
   address narrator;

   IERC1155Arena arena;

   uint256 narratorId;

  function setup_deployedArena() internal {
      tokenDeployer = vm.addr(1);
      operator = vm.addr(2);
      narrator = vm.addr(11);

      arena = IERC1155Arena(LibTestDeploy.newChaintrapArena(vm, tokenDeployer, operator));
  }

  function setup_singleNarratorAccount() internal {
    setup_deployedArena();
    vm.prank(narrator)
    narratorId = arena.createAvatar(AvatarInitArgs("chaintrap/avatars/{id}"), TokenID.NARRATOR_AVATAR);
  }
}
