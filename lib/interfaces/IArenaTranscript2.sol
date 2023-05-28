// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {ActionCommitment} from "lib/libtranscript2.sol";
import {OutcomeArgument} from "lib/libtranscript2.sol";
import {StartGameArgs} from "lib/libtranscript2.sol";

interface IArenaTranscript2 {
    /// ---------------------------
    /// @dev overall game state

    function registerParticipant(uint256 gid, bytes calldata profile) external;

    /// @notice starts a game that is currently in the Initialised state.
    /// You must be the owner of the game to do this.
    function startGame2(uint256 gid, StartGameArgs calldata args) external;

    /// ---------------------------
    /// @dev actions & outcomes

    function commitAction(
        uint256 gid,
        ActionCommitment calldata commitment
    ) external returns (uint256);

    function resolveOutcome(
        uint256 gid,
        OutcomeArgument calldata argument
    ) external;
}
