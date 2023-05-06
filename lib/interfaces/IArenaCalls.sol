// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/game.sol";

interface IArenaCalls {
    function lastGame() external view returns (GameID);

    function playerRegistered(
        GameID gid,
        address p
    ) external view returns (bool);

    function gameStatus(GameID id) external view returns (GameStatus memory);

    /// @notice get the number of players currently known to the game (they may not be registered by the host yet)
    /// @param gid game id
    /// @return number of known players
    function playerCount(GameID gid) external view returns (uint8);

    /// @notice returns the numbered player record from storage
    /// @dev we account for the zeroth invalid player slot automatically
    /// @param gid gameid
    /// @param _iplayer player number. numbers range over 0 to playerCount() - 1
    /// @return player storage reference
    function player(
        GameID gid,
        uint8 _iplayer
    ) external view returns (Player memory);

    function player(
        GameID gid,
        address _player
    ) external view returns (Player memory);
}
