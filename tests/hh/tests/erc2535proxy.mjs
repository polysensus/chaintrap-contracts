import { expect } from "chai";
import hre from "hardhat";
const {ethers} = hre;
import { deployArena } from "./deploy.js";
// import arenaCallsFacetABI from "@polysensus/chaintrap-contracts/abi/ArenaCallsFacet.json" assert { type: "json" };
import diamondSol from "../../../abi/Diamond.json" assert { type: "json" };
import arenaCallsFacetSol from "../../../abi/ArenaCallsFacet.json" assert { type: "json" };
import { createERC2535Proxy } from "../../../chaintrap/erc2535proxy.mjs"

describe("ERC2535Proxy", async function (){
  let proxy;

  before(async function () {
    proxy = await deployArena();
  })

  it("Should access lastGame", async function() {

    const arena = createERC2535Proxy(
      proxy.address, diamondSol.abi, {
        ArenaCallsFacet: arenaCallsFacetSol.abi
      },
      ethers.getSigners()[0]);

    const lastGame = arena.lastGame;
    expect(lastGame).to.not.be.undefined;
  })
})

