// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {GameIsInitialised, InvalidProof} from "lib/transcript2.sol";
import {LibGame, Transcript2, TranscriptInitArgs} from "lib/transcript2.sol";

import {TranscriptWithFactory, TranscriptInitUtils } from "tests/TranscriptUtils.sol";

contract LibGame__init is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {
    using LibGame  for Transcript2;
    using stdStorage for StdStorage;

    function test_commitAction() public {
        f.pushGame();
    }

    function test__init_RevertInitialiseTwice() public {
        f.pushGame();
        f._init(1, minimalyValidInitArgs());

        vm.expectRevert(GameIsInitialised.selector);
        f._init(1, minimalyValidInitArgs());
    }

    function test__init_RevertMoreRootsThanLabels() public {
        f.pushGame();

        vm.expectRevert(stdError.indexOOBError); // array out of bounds
        f._init(1, TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels:new bytes32[](1),
            roots:new bytes32[](2)}
            ));
    }

    function test__init_NoRevertFewerRootsThanLabels() public {
        f.pushGame();

        f._init(1, TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels:new bytes32[](2),
            roots:new bytes32[](1)}
            ));
    }

    function test__init_EmitSetMerkleRoot() public {
        f.pushGame();

        vm.expectEmit(true, true, true, true);

        // Should get one emit for each root
        emit LibGame.SetMerkleRoot(1, "", "");
        emit LibGame.SetMerkleRoot(1, "", "");

        f._init(1, TranscriptInitArgs({
            tokenURI: "tokenURI",
            rootLabels:new bytes32[](2),
            roots:new bytes32[](2)}
            ));
    }
}