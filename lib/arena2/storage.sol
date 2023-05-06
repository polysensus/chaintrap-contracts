// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {LibGame, Game2} from "lib/game2.sol";

library LibArena2Storage {
    struct Layout {
        Game2[] games;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("Arena2.storage.contracts.chaintrap.polysensus");

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /// @notice idempotent initialisation for the zero states.
    function _idempotentInit() internal {
        LibArena2Storage.Layout storage s = layout();
        if (s.games.length == 0) {
            s.games.push();
            s.games[0].state = LibGame.GameState.Invalid;
        }
    }
}
