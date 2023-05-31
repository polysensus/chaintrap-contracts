// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {LibTranscript, Transcript} from "lib/libtranscript.sol";

library LibArenaStorage {
    struct Layout {
        uint256 lastGameId;
        mapping(uint256 => Transcript) games;
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
        LibArenaStorage.Layout storage s = layout();
        if (s.lastGameId == 0) {
            s.games[s.lastGameId].state = LibTranscript.State.Invalid;
            s.lastGameId = 1;
        }
    }
}
