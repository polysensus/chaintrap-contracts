// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "lib/interfaces/ITranscriptErrors.sol";
import {LibTranscript} from "lib/libtranscript.sol";
import {
    TranscriptWithFactory, TranscriptInitUtils
} from "tests/TranscriptUtils.sol";

contract LibTranscript_registerParticipant is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {

    function test_registerParticipant() public {
        f.pushTranscript();
        f._init(1, address(1), minimalyValidInitArgs());

        address participant = address(9);
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.TranscriptRegistration(1, participant, "player one");
        f.register(participant, "player one");
    }

    function test_revert_ifDuplicateRegistration() public {
        f.pushTranscript();
        f._init(1, address(1), minimalyValidInitArgs());

        address participant = address(9);
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.TranscriptRegistration(1, participant, "");
        f.register(participant, "");

        vm.expectRevert(Transcript_AlreadyRegistered.selector);
        f.register(participant, "");
    }

    function test_revert_ifGameStarted() public {
        f.pushTranscript();
        f._init(1, address(1), minimalyValidInitArgs());
        f.forceGameState(LibTranscript.State.Started);

        vm.expectRevert(Transcript_RegistrationClosed.selector);
        f.register(address(1), "");
    }
}
