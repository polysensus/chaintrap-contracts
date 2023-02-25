// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/game.sol";

interface IArena {

    /// ---------------------------------------------------
    /// @dev game setup creation & player signup
    /// ---------------------------------------------------

    function joinGame(
        GameID gid, bytes calldata profile
    ) external;

    function _joinGame(
        GameID gid, address p, bytes calldata profile
    ) external;

    function setStartLocation(
        GameID gid, address p, bytes32 startLocation, bytes calldata sceneblob
    ) external;

    function placeFurniture(
        GameID gid, bytes32 placement, uint256 id) external;

    /// ---------------------------------------------------
    /// @dev game phase transitions
    /// ---------------------------------------------------

    function startGame(GameID gid) external;

    function completeGame(GameID gid) external;

    /// ---------------------------------------------------
    /// @dev game progression
    /// ---------------------------------------------------
    function reject(GameID gid, TEID id, bool halt) external;

    function allowAndHalt(GameID gid, TEID id) external;

    // --- move specific commit/allow methods

    /// @dev commitExitUse is called by a registered player to commit to using a specific exit.
    function commitExitUse(GameID gid, ExitUse calldata committed)  external returns (TEID);

    /// @dev allowExitUse is called by the game master to declare the outcome of the players commited exit use.
    function allowExitUse(GameID gid, TEID id, ExitUseOutcome calldata outcome) external;


    /// @dev commitFurnitureUse is called by any participant to bind a token to a game session.
    /// The effect of this on the game session is token specific
    function commitFurnitureUse(
        GameID gid, FurnitureUse calldata committed)  external returns (TEID);

    /// @dev allowFurnitureUse is called by the game master to declare the outcome of the participants commited token use.
    /// Note that for placement of map items before the game start, the host can 'self allow'
    function allowFurnitureUse(
        GameID gid, TEID id, FurnitureUseOutcome calldata outcome) external;
}
