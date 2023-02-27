import hre from "hardhat";
import { expect } from "chai";
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
// import deploypkg from "./deploy.mjs";
// const { deployArena } = deploypkg;
import { deployArenaFixture } from "./deploy.js";
import { createArenaProxy } from "./arenaproxy.mjs";

describe("Arena", async function () {
  let proxy;
  let owner;

  it("Should create a new game and transcript both with the first ids", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.status, 1);
    expect(r.events[1].args.gid).to.equal(1);
    expect(r.events[1].args.tid).to.equal(1);
  });
  it("Should create two games", async function () {

    [proxy, owner] = await loadFixture(deployArenaFixture);
    const arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.status, 1);
    expect(r.events[1].args.gid).to.equal(1);
    expect(r.events[1].args.tid).to.equal(1);
    tx = await arena.createGame(2, "");
    r = await tx.wait();
    expect(r.events[1].args.gid).to.equal(2);
    expect(r.events[1].args.tid).to.equal(2);
  });

  it("Should keep game and transcript ids after resetting map", async function () {

    [proxy, owner] = await loadFixture(deployArenaFixture);
    let arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.status, 1);
    const gid = r.events[1].args.gid;
    arena = arena.getFacet('ArenaTranscriptsFacet');
    tx = await arena.reset(gid);
    r = await tx.wait();
    expect(r.status, 1);
  });

});
