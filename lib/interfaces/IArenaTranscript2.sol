// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

interface IArenaTranscript2 {
    function registerParticipant(uint256 gid, bytes calldata profile) external;
}
