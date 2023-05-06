// SPDX-License-Identifier: MIT

pragma solidity =0.8.9;

import {IERC173} from "@solidstate/contracts/interfaces/IERC173.sol";
import {IOwnableInternal} from "@solidstate/contracts/access/ownable/IOwnableInternal.sol";
import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import {AddressUtils} from "@solidstate/contracts/utils/AddressUtils.sol";

abstract contract ModOwnable is IOwnableInternal {
    using AddressUtils for address;

    modifier onlyOwner() {
        if (msg.sender != _owner()) revert Ownable__NotOwner();
        _;
    }

    modifier onlyTransitiveOwner() {
        if (msg.sender != _transitiveOwner())
            revert Ownable__NotTransitiveOwner();
        _;
    }

    function _owner() internal view virtual returns (address) {
        return OwnableStorage.layout().owner;
    }

    function _transitiveOwner() internal view virtual returns (address owner) {
        owner = _owner();

        while (owner.isContract()) {
            try IERC173(owner).owner() returns (address transitiveOwner) {
                owner = transitiveOwner;
            } catch {
                break;
            }
        }
    }
}
