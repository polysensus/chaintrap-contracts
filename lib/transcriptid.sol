// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
type TID is uint256;
TID constant invalidTID = TID.wrap(0);

type TEID is uint16;
TEID constant invalidTEID = TEID.wrap(0);

/// @dev due to how the enumeration `next` method works, the initial cur value must be 0
TEID constant cursorStart = TEID.wrap(0);
TEID constant cursorUntilEnd = TEID.wrap(0);
