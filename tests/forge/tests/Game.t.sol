// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "lib/game.sol";

contract GameTest is DSTest {
    using Games for Game;
    using stdStorage for StdStorage;

    Vm private vm = Vm(HEVM_ADDRESS);
    Game[] games;

    StdStorage private stdstore;

    function setUp() public {
        // Deploy Map contract
        games.push();
    }

    function emptyGame() internal returns (Game storage) {
        uint256 i = games.length;
        games.push();
        return games[i];
    }

    function testFailZeroAddress() public {
        Game storage g = emptyGame();
        g.player(address(0));
    }
}
