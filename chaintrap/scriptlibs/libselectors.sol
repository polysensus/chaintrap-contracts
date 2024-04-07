// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Vm} from "forge-std/Vm.sol";

string constant CONTRACTSELECTORS_JS = "scripts/contractselectors.js";

library LibSelectors {
    // return the bytes4[] of *sorted* selectors for the provided contact name
    function listSelectors(
        Vm vm,
        string memory contractName
    ) internal returns (bytes4[] memory) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = CONTRACTSELECTORS_JS;
        cmd[2] = contractName;
        // cmd[3] = '{"exclude":"init(bytes)"}'
        bytes memory output = vm.ffi(cmd);
        // string memory st = string(res);

        bytes4[] memory selectors = abi.decode(output, (bytes4[]));
        return selectors;
    }

    // --- often needed utility methods for selector arrays

    /// @dev remove the item at index i from the array
    function removeElement(
        uint index,
        bytes4[] memory array
    ) public pure returns (bytes4[] memory) {
        bytes4[] memory newarray = new bytes4[](array.length - 1);
        uint j = 0;
        for (uint i = 0; i < array.length; i++) {
            if (i != index) {
                newarray[j] = array[i];
                j += 1;
            }
        }
        return newarray;
    }

    // helper to remove value from bytes4[] array
    /// @dev remove the item matching el from the array
    function removeElement(
        bytes4 el,
        bytes4[] memory array
    ) public pure returns (bytes4[] memory) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == el) {
                return removeElement(i, array);
            }
        }
        return array;
    }
}
