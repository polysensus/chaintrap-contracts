// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import {Test} from "forge-std/Test.sol";
import {LibArenaStorage} from "chaintrap/arena/storage.sol";
import {TokenID} from "chaintrap/tokenid.sol";
// import "forge-std/console2.sol";


contract LibArenaStorage_init is Test {
    using LibArenaStorage for LibArenaStorage.Layout;

    function test_initGameIdLastFirstTime() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s._initGameId();
        assertEq(s.sequenceLast[TokenID.GAME2_TYPE], 1);
    }

    function test_initGameIdLastIdempotentLegacy() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.lastGameId = 2;
        s._initGameId();
        assertEq(s.sequenceLast[TokenID.GAME2_TYPE], 2);
    }

    function test_initGameIdLastIdempotent() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.lastGameId = 2;
        s.sequenceLast[TokenID.GAME2_TYPE] = 2;
        s._initGameId();
        assertEq(s.sequenceLast[TokenID.GAME2_TYPE], 2);
    }

    function test_initSeqLastFirstTime() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        // Note: there is no opinion asserted at the storage layout level
        // regarding valid 'types'
        s._initSeq(123);
        assertEq(s.sequenceLast[123], 1);
    }

    function test_initSeqIdempotent() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();
        s.sequenceLast[123] = 2;
        s._initSeq(123);
        assertEq(s.sequenceLast[123], 2);
    }

    function test_idempotentInitFirstTime() public {
        LibArenaStorage.Layout storage s = LibArenaStorage.layout();

        LibArenaStorage._idempotentInit();

        assertEq(s.sequenceLast[TokenID.GAME2_TYPE], 1);
        assertEq(s.sequenceLast[TokenID.MODERATOR_AVATAR], 1);
        assertEq(s.sequenceLast[TokenID.NARRATOR_AVATAR], 1);
        assertEq(s.sequenceLast[TokenID.RAIDER_AVATAR], 1);
        assertEq(s.sequenceLast[TokenID.NARRATOR_TICKET], 1);
        assertEq(s.sequenceLast[TokenID.RAIDER_TICKET], 1);
    }
}
