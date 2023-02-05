// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Script.sol";

import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";
import {DiamondCutFacet} from "diamond/facets/DiamondCutFacet.sol";
import {DiamondNew, DiamondNewArgs, IDiamondNew} from "chaintrap/upgradeinit/DiamondNew.sol";

import {Diamond} from "diamond/Diamond.sol";

contract DeployScript is Script {

    IDiamondCut.FacetCut[] private _facetCuts;

    function getSelectors(string memory _facetName)
        internal
        returns (bytes4[] memory selectors)
    {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/contractselectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function run() external {

        // This deploys a new diamond. Which means its state is completely fresh

        uint256 operatorKey = vm.envUint("CHAINTRAP_CONTRACTS_OPERATOR_KEY");
        address operatorAddr = vm.addr(operatorKey);
        vm.startBroadcast(operatorKey);

        // Start by deploying the DiamondCut and DiamondInit contracts
        DiamondCutFacet cutter = new DiamondCutFacet();
        DiamondNew diamondNew = new DiamondNew();
        Diamond diamond = new Diamond(operatorAddr,  address(cutter));

        // Register all facets.
        string[5] memory facets = [
            // Native facets,
            "DiamondLoupeFacet",
            "OwnershipFacet",
            // // Protocol facets.
            "ArenaFacet",
            "ArenaCalls",
            "ArenaERC1155"
            // "ArenaTranscripts"
        ];

        // Loop on each facet, deploy them and create the FacetCut.
        for (uint256 facetIndex = 0; facetIndex < facets.length; facetIndex++) {
            string memory facet = facets[facetIndex];

            // Deploy the facet.
            bytes memory bytecode = vm.getCode(string(string.concat(bytes(facet), ".sol")));
            address facetAddress;
            assembly {
                facetAddress := create(0, add(bytecode, 0x20), mload(bytecode))
            }

            // Get the facet selectors.
            bytes4[] memory selectors = getSelectors(facet);

            // Create the FacetCut struct for this facet.
            _facetCuts.push(
                IDiamondCut.FacetCut({
                    facetAddress: facetAddress,
                    action: IDiamondCut.FacetCutAction.Add,
                    functionSelectors: selectors
                })
            );
        }

        string[] memory typeURIs = new string[](3);
        typeURIs[0]="GAME_TYPE";
        typeURIs[1]="TRANSCRIPT_TYPE";
        typeURIs[2]="FURNITURE_TYPE";
        DiamondNewArgs memory diamondArgs = DiamondNewArgs({ typeURIs: typeURIs });

        // NOTE: "interfaceId" can be used since "init" is the only function in IDiamondInit.
        IDiamondCut(address(diamond)).diamondCut(_facetCuts, address(diamondNew), abi.encode(type(IDiamondNew).interfaceId, diamondArgs));

        vm.stopBroadcast();
    }
}

