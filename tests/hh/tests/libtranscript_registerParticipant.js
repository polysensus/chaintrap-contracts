import hre from "hardhat";
const ethers = hre.ethers;
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployArenaFixture } from "./deploy.js";
import { createArenaProxy } from "./arenaproxy.js";

import { createGame } from "./libtranscript_helpers.js";

describe("LibTranscript_registerParticipant", async function () {
  let proxy;
  let owner;

  it("Should register participant", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);
    let { r } = await createGame(arena, {
      tokenURI: "",
      registrationLimit: 2,
      roots: {
        a_root_label:
          "0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
      },
      choiceInputTypes: [1],
      transitionTypes: [2, 3],
      victoryTransitionTypes: [4],
      haltParticipantTransitionTypes: [],
    });

    expect(r.status).to.equal(1);

    const gid = r.events?.[0]?.args?.id;
    expect(gid?.and(1)).to.equal(ethers.BigNumber.from(1));

    const tx = await arena.registerTrialist(
      gid,
      ethers.utils.toUtf8Bytes("player one")
    );
    r = await tx.wait();
    expect(r.status).to.equal(1);
  });
});
