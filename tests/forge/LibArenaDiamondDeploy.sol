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

import "tests/strings.sol";

import {HEVM_ADDRESS} from "tests/constants.sol";
import {Vm} from "forge-std/Vm.sol";

library ArenaTestStorage {
    struct Layout {
        Vm vm;
        // cuts is a convenience so we can use .push to assemble them. Any
        // method that uses this storage array will start by deleting the
        // current array
        IDiamondCut.FacetCut[] cuts;
        Diamond arena;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('ArenaTestStorage.forge.tests.contracts.chaintrap.polysensus');

    function layout() internal pure returns (Layout storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}

library LibArenaDiamondDeploy {
    using strings for *;

    function defaultSetup(address operator) internal {
        ArenaTestStorage.Layout storage s = ArenaTestStorage.layout();
        s.vm = Vm(HEVM_ADDRESS);

        // Diamond deploy, the cutter is the only facet needed by the diamon on
        // construction.
        DiamondCutFacet cutter = new DiamondCutFacet();

        s.arena = new Diamond(operator,  address(cutter));

        DiamondNew diamondNew = new DiamondNew();

        // This is the only collision
        bytes4 supportsInterface = 0x01ffc9a7;

        delete s.cuts; // reset the cuts

        address facet;

        facet =  address(new DiamondLoupeFacet());
        s.cuts.push(IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
            }));

        facet = address(new OwnershipFacet());
        s.cuts.push(IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
            }));

        facet = address(new ArenaFacet());
        s.cuts.push(IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSelectors("ArenaFacet")
            }));


        facet = address(new ERC1155ArenaFacet());
        s.cuts.push(IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: removeElement(supportsInterface, generateSelectors("ERC1155ArenaFacet"))
            }));

        string[] memory typeURIs = new string[](3);
        typeURIs[0]="GAME_TYPE";
        typeURIs[1]="TRANSCRIPT_TYPE";
        typeURIs[2]="FURNITURE_TYPE";
        DiamondNewArgs memory diamondNewArgs = DiamondNewArgs({ typeURIs: typeURIs});

        s.vm.prank(operator, operator);
        // NOTE: "interfaceId" can be used since "init" is the only function in IDiamondNew
        IDiamondCut(address(s.arena)).diamondCut(
            s.cuts, address(diamondNew), abi.encode(type(IDiamondNew).interfaceId, diamondNewArgs));
    }

    /* for another time
    function readFacetExclusions(string memory exclusionsJsonFile) {

        Vm vm = Vm(HEVM_ADDRESS);
        string memory json = vm.readFile(exclusionsJsonFile);
        bytes memory abiData = vm.parseJson(json);

        FacetExclusions[] memory fe;

    }*/

    // return array of function selectors for given facet name
    function generateSelectors(
        string memory _facetName
        ) internal returns (bytes4[] memory selectors)
    {
        ArenaTestStorage.Layout storage store = ArenaTestStorage.layout();
        //get string of contract methods
        string[] memory cmd = new string[](4);
        cmd[0] = "forge";
        cmd[1] = "inspect";
        cmd[2] = _facetName;
        cmd[3] = "methods";
        bytes memory res = store.vm.ffi(cmd);
        string memory st = string(res);

        // extract function signatures and take first 4 bytes of keccak
        strings.slice memory s = st.toSlice();
        strings.slice memory delim = ":".toSlice();
        strings.slice memory delim2 = ",".toSlice();
        selectors = new bytes4[]((s.count(delim)));
        for(uint i = 0; i < selectors.length; i++) {
            s.split('"'.toSlice());
            selectors[i] = bytes4(s.split(delim).until('"'.toSlice()).keccak());
            s.split(delim2);

        }
        return selectors;
    }

    function removeElement(uint index, bytes4[] memory array) public pure returns (bytes4[] memory){
        bytes4[] memory newarray = new bytes4[](array.length-1);
        uint j = 0;
        for(uint i = 0; i < array.length; i++){
            if (i != index){
                newarray[j] = array[i];
                j += 1;
            }
        }
        return newarray;

    }

    // helper to remove value from bytes4[] array
    function removeElement(bytes4 el, bytes4[] memory array) public pure returns (bytes4[] memory){
        for(uint i = 0; i < array.length; i++){
            if (array[i] == el){
                return removeElement(i, array);
            }
        }
        return array;

    }
}