import hre from "hardhat";
import { ethers, Signer, Provider } from "ethers";
import diamondSol from "../../../abi/Diamond.json";
import diamondCutFacetSol from "../../../abi/DiamondCutFacet.json";
import diamondLoupeFacetSol from "../../../abi/DiamondLoupeFacet.json";
import ownershipFacetSol from "../../../abi/OwnershipFacet.json";
import arenaFacetSol from "../../../abi/ArenaFacet.json";
import erc1155ArenaFacetSol from "../../../abi/ERC1155ArenaFacet.json";
import {
  createERC2535Proxy,
  FacetInterfaces,
} from "../../../chaintrap/erc2535proxy";

const facetABIs: FacetInterfaces = {
  DiamondCutFacet: diamondCutFacetSol.abi,
  DiamondLoupeFacet: diamondLoupeFacetSol.abi,
  OwnershipFacet: ownershipFacetSol.abi,
  ArenaFacet: arenaFacetSol.abi,
  ERC1155ArenaFacetSol: erc1155ArenaFacetSol.abi,
};

export function createArenaProxy(
  diamondAddress: string,
  providerOrSigner: Signer | Provider
) {
  const arena = createERC2535Proxy(
    diamondAddress,
    diamondSol.abi,
    facetABIs,
    providerOrSigner
  );
  return arena;
}
