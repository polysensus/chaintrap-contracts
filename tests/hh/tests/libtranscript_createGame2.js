import hre from "hardhat";
const ethers = hre.ethers;
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployArenaFixture } from "./deploy.js";
import { createArenaProxy } from "./arenaproxy.js";

describe("LibTranscript_createGame2", async function () {
  let proxy;
  let owner;

  it("Should create a new game2", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame2({
      tokenURI: "",
      rootLabels: [ethers.utils.formatBytes32String("a-root-label")],
      roots: [
        "0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
      ],
    });
    let r = await tx.wait();
    expect(r.status).to.equal(1);
    expect(r.events?.[0]?.args?.id?.and(1)).to.equal(ethers.BigNumber.from(1));
  });
});
