import { expect } from "chai";
import hre from "hardhat";
const { ethers } = hre;
import { deployArenaFixture } from "./deploy.js";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

// import arenaCallsFacetABI from "@polysensus/chaintrap-contracts/abi/ArenaCallsFacet.json" assert { type: "json" };
import diamondSol from "../../../abi/Diamond.json" assert { type: "json" };
import arenaCallsFacetSol from "../../../abi/ArenaCallsFacet.json" assert { type: "json" };
import { createERC2535Proxy } from "../../../chaintrap/erc2535proxy.js";

describe("ERC2535Proxy", async function () {
  let proxy;

  it("Should access lastGame", async function () {
    [proxy] = await loadFixture(deployArenaFixture);
    const arena = createERC2535Proxy(
      proxy,
      diamondSol.abi,
      {
        ArenaCallsFacet: arenaCallsFacetSol.abi,
      },
      ethers.getSigners()[0]
    );

    const lastGame = arena.lastGame;
    expect(lastGame).to.not.be.undefined;
  });
});
