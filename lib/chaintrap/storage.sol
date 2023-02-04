// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "lib/game.sol";
import "lib/furnishings.sol";

library ChaintrapStorage {
    struct Layout {

        Game[] games;
        Transcript[] transcripts;
        Furniture[] furniture;

        /// @dev to allow game loading mistakes to be rectified we allow a game to
        /// be discarded. This means there is a many - 1 relationship from  games to
        /// transcripts. The transcript can only be produced once by actual player
        /// interaction. The game state we can re-create at will.
        mapping (GameID => TID) gid2tid;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('polysensus.contracts.storage.ChaintrapStorage');

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}


