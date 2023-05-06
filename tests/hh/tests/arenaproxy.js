import hre from "hardhat";
const { ethers } = hre;
import diamondSol from "../../../abi/Diamond.json" assert { type: "json" };
import diamondCutFacetSol from "../../../abi/DiamondCutFacet.json" assert { type: "json" };
import diamondLoupeFacetSol from "../../../abi/DiamondLoupeFacet.json" assert { type: "json" };
import ownershipFacetSol from "../../../abi/OwnershipFacet.json" assert { type: "json" };
import arenaCallsFacetSol from "../../../abi/ArenaCallsFacet.json" assert { type: "json" };
import arenaFacetSol from "../../../abi/ArenaFacet.json" assert { type: "json" };
import arenaTranscriptsFacetSol from "../../../abi/ArenaTranscriptsFacet.json" assert { type: "json" };
import erc1155ArenaFacetSol from "../../../abi/ERC1155ArenaFacet.json" assert { type: "json" };

import { createERC2535Proxy } from "../../../chaintrap/erc2535proxy.js";

export const facetABIs = {
  DiamondCutFacet: diamondCutFacetSol.abi,
  DiamondLoupeFacet: diamondLoupeFacetSol.abi,
  OwnershipFacet: ownershipFacetSol.abi,
  ArenaCallsFacet: arenaCallsFacetSol.abi,
  ArenaFacet: arenaFacetSol.abi,
  ArenaTranscriptsFacet: arenaTranscriptsFacetSol.abi,
  ERC1155ArenaFacetSol: erc1155ArenaFacetSol.abi,
};

export function createArenaProxy(diamondAddress, providerOrSigner) {
  const arena = createERC2535Proxy(
    diamondAddress,
    diamondSol.abi,
    facetABIs,
    providerOrSigner
  );
  return arena;
}
