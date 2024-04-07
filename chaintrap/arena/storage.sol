// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {LibTranscript, Transcript} from "chaintrap/libtranscript.sol";
import {TokenID} from "chaintrap/tokenid.sol";

error IDSequenceNotInitialised(uint256 which);

library LibArenaStorage {
    struct Layout {
        uint256 lastGameId;
        mapping(uint256 => Transcript) games;
        mapping(uint256 => uint256) sequenceLast;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("Arena2.storage.contracts.chaintrap.polysensus");

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    function nextSeq(
        LibArenaStorage.Layout storage s,
        uint256 ty
    ) internal returns (uint256) {
        if (s.sequenceLast[ty] == 0) revert IDSequenceNotInitialised(ty);
        uint256 allocatedId = s.sequenceLast[ty];
        s.sequenceLast[ty] += 1;
        return allocatedId;
    }

    /// @notice idempotent initialisation for the zero states.
    function _idempotentInit() internal {
        LibArenaStorage.Layout storage s = layout();
        _initGameId(s); // TokenID.GAME2_TYPE needs special treatment due to its history
        _initSeq(s, TokenID.MODERATOR_AVATAR);
        _initSeq(s, TokenID.NARRATOR_AVATAR);
        _initSeq(s, TokenID.RAIDER_AVATAR);
        _initSeq(s, TokenID.NARRATOR_TICKET);
        _initSeq(s, TokenID.RAIDER_TICKET);
    }

    function _initSeq(LibArenaStorage.Layout storage s, uint256 ty) internal {
        if (s.sequenceLast[ty] != 0) return;
        s.sequenceLast[ty] = 1;
    }

    function _initGameId(LibArenaStorage.Layout storage s) internal {
        if (s.sequenceLast[TokenID.GAME2_TYPE] != 0) return;
        if (s.lastGameId != 0) {
            s.sequenceLast[TokenID.GAME2_TYPE] = s.lastGameId;
            return;
        }
        s.sequenceLast[TokenID.GAME2_TYPE] = 1;
    }
}
