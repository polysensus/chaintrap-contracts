// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {TranscriptCommitment} from "chaintrap/libtranscript.sol";
import {TranscriptOutcome} from "chaintrap/libtranscript.sol";
import {TranscriptStartArgs} from "chaintrap/libtranscript.sol";

interface IArenaTranscript {
    function registerTrialist(uint256 gid, bytes calldata profile) external;

    /// @notice starts a new transcript. You must be the owner of the transcript to do this.
    function startTranscript(
        uint256 gid,
        TranscriptStartArgs calldata args
    ) external;

    /// @notice as a participant, commit to one of the available choices.
    function transcriptEntryCommit(
        uint256 gid,
        TranscriptCommitment calldata commitment
    ) external returns (uint256);

    /// @notice as the transcript creator, or their advocate, accept or reject the participants commitment.
    function transcriptEntryResolve(
        uint256 gid,
        TranscriptOutcome calldata argument
    ) external;
}
