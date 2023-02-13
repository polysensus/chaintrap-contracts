// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "@solidstate/contracts/security/PausableStorage.sol";

// Mod xxx files implement modifiers and the readonly internal methods strictly
// required to support them

/**
 * @title Modifiers for Pausable security control module.
 * @dev derived from @solidstate/contracts/security/PausableInternal.sol
 */
abstract contract ModPausable {
    error Pausable__Paused();
    error Pausable__NotPaused();

    modifier whenNotPaused() {
        if (_paused()) revert Pausable__Paused();
        _;
    }

    modifier whenPaused() {
        if (!_paused()) revert Pausable__NotPaused();
        _;
    }

    /**
     * @notice query the contracts paused state.
     * @return true if paused, false if unpaused.
     */
    function _paused() internal view virtual returns (bool) {
        return PausableStorage.layout().paused;
    }
}
