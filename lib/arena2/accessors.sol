// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {LibArena2Storage} from "./storage.sol";
import {GameID} from "lib/gameid.sol";
import {LibGame, Game2} from "lib/game2.sol";
import {GameIsInvalid} from "lib/game2.sol";

library LibArena2Accessors {
    /// @dev return the game storage or revert with GameIsInvalid if its not a
    /// usable entry (array element 0 is invalid always)
    function game(GameID id) internal view returns (Game2 storage) {
        Game2 storage g = LibArena2Storage.layout().games[GameID.unwrap(id)];
        if (g.state == LibGame.GameState.Invalid) revert GameIsInvalid();
        return g;
    }
}
