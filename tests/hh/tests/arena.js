import hre from "hardhat";
const ethers = hre.ethers;
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployArenaFixture } from "./deploy.js";
import { createArenaProxy, facetABIs } from "./arenaproxy.js";

describe("Arena", async function () {
  let proxy;
  let owner;

  it("Should get the correct event filter from proxy", async function () {
    [proxy, owner] = await loadFixture(deployArenaFixture);
    const arena = createArenaProxy(proxy, owner);

    const filterFromArena = arena.getFilter("GameCreated");

    // check the filter fetched from the cache too
    const filterFromArena2 = arena.getFilter("GameCreated");

    const iface = new ethers.utils.Interface(facetABIs.ArenaFacet);
    const facet = new ethers.Contract(proxy, iface, owner);

    const filterFromFacet = facet.filters["GameCreated"]();

    expect(filterFromArena).to.deep.equal(filterFromFacet);
    expect(filterFromArena2).to.deep.equal(filterFromFacet);
  });

  it("Should create a new game and transcript both with the first ids", async function () {
    // Need a fresh proxy to get the gids we expect
    [proxy, owner] = await loadFixture(deployArenaFixture);

    const arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame({
      maxPlayers: 2,
      tokenURI: "",
      mapVRFBeta: "0x",
    });
    let r = await tx.wait();
    expect(r.status, 1);
    expect(r.events[1].args.gid).to.equal(1);
    expect(r.events[1].args.tid).to.equal(1);
  });
  it("Should create two games", async function () {
    [proxy, owner] = await loadFixture(deployArenaFixture);
    const arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame({
      maxPlayers: 2,
      tokenURI: "",
      mapVRFBeta: "0x",
    });
    let r = await tx.wait();
    expect(r.status, 1);
    expect(r.events[1].args.gid).to.equal(1);
    expect(r.events[1].args.tid).to.equal(1);
    tx = await arena.createGame({
      maxPlayers: 2,
      tokenURI: "",
      mapVRFBeta: "0x",
    });
    r = await tx.wait();
    expect(r.events[1].args.gid).to.equal(2);
    expect(r.events[1].args.tid).to.equal(2);
  });

  it("Should keep game and transcript ids after resetting map", async function () {
    [proxy, owner] = await loadFixture(deployArenaFixture);
    let arena = createArenaProxy(proxy, owner);

    let tx = await arena.createGame({
      maxPlayers: 2,
      tokenURI: "",
      mapVRFBeta: "0x",
    });
    let r = await tx.wait();
    expect(r.status, 1);
    const gid = r.events[1].args.gid;
    arena = arena.getFacet("ArenaTranscriptsFacet");
    tx = await arena.reset(gid);
    r = await tx.wait();
    expect(r.status, 1);
  });
});
