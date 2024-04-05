// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {TranscriptInitArgs} from "chaintrap/libtranscriptstructs.sol";

struct TrialistState {
    uint256 flags;
    uint256 lives;
}

struct TrialistInitArgs {
    uint256 flags;
    uint256 lives;
}

uint256 constant TRIALISTSTATE_FLAG_INITIALISED = 0x0000000000000000000000000000000000000000000000000000000000000001;

/// ---------------------------
/// @dev TrialistState read methods

function trialistIsInitialised(
    TrialistState storage state
) view returns (bool) {
    return
        (state.flags & TRIALISTSTATE_FLAG_INITIALISED) ==
        TRIALISTSTATE_FLAG_INITIALISED;
}

function trialistInitCheck(TrialistInitArgs calldata args) pure returns (bool) {
    if (args.lives == 0) return false;
    return true;
}

/// ---------------------------
/// @dev TrialistState update methods
/// NOTICE! The caller is responsible for doing the appropriate checks (by calling
/// trialistInitCheck for example), these functions are effects only
function trialistInit(
    TrialistState storage state,
    TrialistInitArgs storage args
) {
    state.flags = args.flags;

    // Whatever other flags are set, the INITIALISED flag is un-conditional
    state.flags |= TRIALISTSTATE_FLAG_INITIALISED;
    state.lives = args.lives;
}
