const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Arena", function () {
  it("Should create a new game and transcript both with the first ids", async function () {
    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.events[0].args.gid).to.equal(1);
    expect(r.events[0].args.tid).to.equal(1);
  });
  it("Should create two games", async function () {
    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.events[0].args.gid).to.equal(1);
    expect(r.events[0].args.tid).to.equal(1);
    tx = await arena.createGame(2, "");
    r = await tx.wait();
    expect(r.events[0].args.gid).to.equal(2);
    expect(r.events[0].args.tid).to.equal(2);
  });

  it("Should keep game and transcript ids after resetting map", async function () {
    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    expect(r.events[0].args.gid).to.equal(1);
    expect(r.events[0].args.tid).to.equal(1);
    tx = await arena.reset(r.events[0].args.gid);
    r = await tx.wait();
    expect(r.events[0].args.gid).to.equal(1);
    expect(r.events[0].args.tid).to.equal(1);
  });

});
