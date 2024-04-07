// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IDiamondCut} from "chaintrap/diamond/interfaces/IDiamondCut.sol";
import {DiamondCutFacet} from "chaintrap/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "chaintrap/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "chaintrap/diamond/facets/OwnershipFacet.sol";
import {Diamond} from "chaintrap/diamond/Diamond.sol";

import {DiamondNew, DiamondNewArgs, IDiamondNew} from "chaintrap/upgradeinit/DiamondNew.sol";
import {ArenaFacet} from "chaintrap/facets/arena/ArenaFacet.sol";
import {ERC1155ArenaFacet} from "chaintrap/facets/arena/ERC1155ArenaFacet.sol";
import {LibSelectors} from "chaintrap/scriptlibs/libselectors.sol";

// import "tests/strings.sol";

import {HEVM_ADDRESS} from "tests/constants.sol";
import {Vm} from "forge-std/Vm.sol";

library LibTestDeploy {
    // using strings for *;

    function newChaintrapArena(Vm vm, address deployer, address operator) internal returns (address) {

        vm.startPrank(deployer);
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // Diamond deploy, the cutter is the only facet needed by the diamon on
        // construction.
        DiamondCutFacet cutter = new DiamondCutFacet();

        Diamond arena = new Diamond(operator, address(cutter));

        DiamondNew diamondNew = new DiamondNew();

        // This is the only collision
        bytes4 supportsInterface = 0x01ffc9a7;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondLoupeFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: listSelectors("DiamondLoupeFacet")
            });

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(new OwnershipFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: listSelectors("OwnershipFacet")
            });

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(new ArenaFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: listSelectors("ArenaFacet")
            });

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(new ERC1155ArenaFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: removeElement(supportsInterface, listSelectors("ERC1155ArenaFacet"))
            });

        string[] memory typeURIs = new string[](9);
        typeURIs[0]="GAME_TYPE";
        typeURIs[1]="TRANSCRIPT_TYPE";
        typeURIs[2]="FURNITURE_TYPE";
        typeURIs[3]="GAME2_TYPE";
        typeURIs[4]="MODERATOR_AVATAR";
        typeURIs[5]="NARRATOR_AVATAR";
        typeURIs[6]="RAIDER_AVATAR";
        typeURIs[7]="NARRATOR_TICKET";
        typeURIs[8]="RAIDER_TICKET";
        DiamondNewArgs memory diamondNewArgs = DiamondNewArgs({ typeURIs: typeURIs});

        // switch to the operator for the cutting
        vm.stopPrank();

        vm.prank(operator, operator);
        // NOTE: "interfaceId" can be used since "init" is the only function in IDiamondNew
        IDiamondCut(address(arena)).diamondCut(
            cuts, address(diamondNew), abi.encode(type(IDiamondNew).interfaceId, diamondNewArgs));

        return address(arena);
    }

    // return array of function selectors for given facet name
    function listSelectors(
        string memory _facetName
        ) internal returns (bytes4[] memory selectors)
    {
      return LibSelectors.listSelectors(Vm(HEVM_ADDRESS), _facetName);
    }

    function removeElement(uint index, bytes4[] memory array) public pure returns (bytes4[] memory){
        return LibSelectors.removeElement(index, array);
    }

    // helper to remove value from bytes4[] array
    function removeElement(bytes4 el, bytes4[] memory array) public pure returns (bytes4[] memory){
      return LibSelectors.removeElement(el, array);
    }
}
