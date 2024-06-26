// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// DiamondNew should only be used on a freshly deployed (empty) chaintrap diamond

import {LibDiamond} from "chaintrap/diamond/libraries/LibDiamond.sol";
import {IDiamondLoupe} from "chaintrap/diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "chaintrap/diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "chaintrap/diamond/interfaces/IERC173.sol";
import {IERC165} from "chaintrap/diamond/interfaces/IERC165.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

import {LibArenaStorage} from "chaintrap/arena/storage.sol";
import {ArenaERC1155Storage} from "chaintrap/erc1155/storage.sol";
import {LibERC1155Arena} from "chaintrap/erc1155/liberc1155arena.sol";

struct DiamondNewArgs {
    string[] typeURIs;
}

interface IDiamondNew {
    function init(DiamondNewArgs calldata args) external;
}

contract DiamondNew {
    function init(DiamondNewArgs calldata args) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        ArenaERC1155Storage._idempotentInit(args.typeURIs);
        LibArenaStorage._idempotentInit();
    }
}
