// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "lib/game.sol";

interface IArenaTranscripts {
    function loadLocations(GameID gid, Location[] calldata locations) external;

    function loadExits(GameID gid, Exit[] calldata exits) external;

    function loadLinks(GameID gid, Link[] calldata links) external;

    function loadTranscriptLocations(
        GameID gid,
        TranscriptLocation[] calldata locations
    ) external;

    /// @notice if a mistake is made loading the game map reset it using this
    /// method. The game and transcript ids are unchanged
    function reset(GameID gid) external;

    /// ---------------------------------------------------
    /// @dev transcript playback
    /// ---------------------------------------------------

    function playTranscript(
        GameID gid,
        TEID cur,
        TEID end
    ) external returns (TEID);
}
