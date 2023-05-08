// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "lib/interfaces/ITranscript2Errors.sol";
import {LibTranscript} from "lib/libtranscript2.sol";
import {
    TranscriptWithFactory, TranscriptInitUtils
} from "tests/TranscriptUtils.sol";

contract LibTranscript_registerParticipant is
    TranscriptWithFactory,
    TranscriptInitUtils,
    DSTest {

    function test_registerParticipant() public {
        f.pushTranscript();
        f._init(1, minimalyValidInitArgs());

        address participant = address(9);
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ParticipantRegistered(1, participant, "player one");
        f.registerParticipant(participant, "player one");
    }

    function test_revert_ifDuplicateRegistration() public {
        f.pushTranscript();
        f._init(1, minimalyValidInitArgs());

        address participant = address(9);
        vm.expectEmit(true, true, true, true);
        emit LibTranscript.ParticipantRegistered(1, participant, "");
        f.registerParticipant(participant, "");

        vm.expectRevert(AlreadyRegistered.selector);
        f.registerParticipant(participant, "");
    }

    function test_revert_ifGameStarted() public {
        f.pushTranscript();
        f._init(1, minimalyValidInitArgs());
        f.forceGameState(LibTranscript.GameState.Started);

        vm.expectRevert(RegistrationIsClosed.selector);
        f.registerParticipant(address(1), "");
    }
}
