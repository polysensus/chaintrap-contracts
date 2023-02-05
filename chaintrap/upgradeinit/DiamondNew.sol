// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

// DiamondNew should only be used on a freshly deployed (empty) chaintrap diamond

import {LibDiamond} from "diamond/libraries/LibDiamond.sol";
import { IDiamondLoupe } from "diamond/interfaces/IDiamondLoupe.sol";
import { IDiamondCut } from "diamond/interfaces/IDiamondCut.sol";
import { IERC173 } from "diamond/interfaces/IERC173.sol";
import { IERC165 } from "diamond/interfaces/IERC165.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

import { ArenaStorage } from "lib/arena/storage.sol";
import { ArenaERC1155Storage } from "lib/erc1155/storage.sol";
import { LibArenaERC1155 } from "lib/erc1155/libarenaerc1155.sol";

struct DiamondNewArgs {
    string []typeURIs;
}

interface IDiamondNew {
    function init(DiamondNewArgs calldata args) external;
}

contract DiamondNew {    

    // You can add parameters to this function in order to pass in 
    // data to set your own state variables
    function init(DiamondNewArgs calldata args) external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;


        // add your own state variables 
        // EIP-2535 specifies that the `diamondCut` function takes two optional 
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface 

        ArenaStorage._initOnce();
        ArenaERC1155Storage._initOnce(args.typeURIs);
    }
}
