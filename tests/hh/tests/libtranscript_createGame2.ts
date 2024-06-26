import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployArenaFixture } from "./deploy";
import { createArenaProxy } from "./arenaproxy";

describe("LibTranscript_createGame2", function () {
  let proxy: string;
  let owner: ethers.Signer;

  it("Should create a new game2", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);

    const tx = await arena.createGame({
      tokenURI: "",
      registrationLimit: 2,
      trialistArgs: { flags: 0, lives: 1 },
      rootLabels: [ethers.utils.formatBytes32String("a-root-label")],
      roots: [
        "0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
      ],
      choiceInputTypes: [1],
      transitionTypes: [2, 3],
      victoryTransitionTypes: [4],
      haltParticipantTransitionTypes: [],
      livesIncrement: [],
      livesDecrement: [],
    });

    const r = await tx.wait();
    expect(r.status).to.equal(1);
    expect(r.events?.[0]?.args?.id?.and(1)).to.equal(ethers.BigNumber.from(1));
  });
});
