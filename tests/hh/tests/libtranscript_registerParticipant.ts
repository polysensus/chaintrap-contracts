import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployArenaFixture } from "./deploy";
import { createArenaProxy } from "./arenaproxy";
import { createGame } from "./libtranscript_helpers";

describe("LibTranscript_registerParticipant", function () {
  let proxy: string;
  let owner: ethers.Signer;

  it("Should register participant", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);
    let { r } = await createGame(arena, {
      tokenURI: "",
      registrationLimit: 2,
      trialistArgs: { flags: 0, lives: 1 },
      roots: {
        a_root_label:
          "0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
      },
      choiceInputTypes: [1],
      transitionTypes: [2, 3],
      victoryTransitionTypes: [4],
      haltParticipantTransitionTypes: [],
      livesIncrement: [],
      livesDecrement: [],
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
