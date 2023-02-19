const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployArena } = require("./deploy.js");

describe("Arena", async function () {
  let proxy;

  before(async function () {
    proxy = await deployArena();
  })

  it("Should create a new game and transcript both with the first ids", async function () {
    // Need a fresh proxy to get the gids we expect
    const proxy = await deployArena();
    const arena = proxy.ERC1155ArenaFacet;

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.status, 1);
    expect(r.events[1].args.gid).to.equal(1);
    expect(r.events[1].args.tid).to.equal(1);
  });
  it("Should create two games", async function () {

    // Need a fresh proxy to get the gids we expect
    const proxy = await deployArena();
    const arena = proxy.ERC1155ArenaFacet;

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
    let arena = proxy.ERC1155ArenaFacet;

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.status, 1);
    const gid = r.events[1].args.gid;
    arena = proxy.ArenaTranscriptsFacet;
    tx = await arena.reset(gid);
    r = await tx.wait();
    expect(r.status, 1);
  });

});
