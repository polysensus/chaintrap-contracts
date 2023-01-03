
const { expect } = require("chai");
const { keccak256 } = require("ethers/lib/utils.js");
const { ethers } = require("hardhat");
bytes = ethers.utils.arrayify;

// const { NORTH, WEST, SOUTH, EAST } = require("libchaintrap/src/constants.mjs");
const _chaintrap = import("../../../chaintrap/chaintrap.mjs");

async function locationSides() {
  const chaintrap = await _chaintrap;
  return chaintrap.locationSides();
}

/* The following layout is the default full map for theses tests

   (not doing corridors at all in this, its all just rooms)

   +------+---------------------------+-----+
   | 1 (1)|-(2)  2                (3)-|-(4) |  
   +-+----+                           |   3 |
     |(9)-|-(5)                       +-----+
     | 4  |(6)              (7)   (8) |
     +----+-|-------+--------|-----|--+
     | 5  (10) (11)-|-(12) 6(13) (14) |
     +--------------+-----------------+

     A full transcript would be

     (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
     (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
     (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
     (6,10)  exitUse(South, 0) ln4 -> (North,0) loc5
     (11,12) exitUse(East, 0)  ln7 -> (West, 0) loc6
     (7,13)  exitUse(North, 0) ln5 -> (South,2) loc2
     (8,14)  exitUse(South, 2) ln6 -> (North,1) loc6
     (8,14)  exitUse(North, 1) ln2 -> (South,2) loc2
     (3,4)   exitUse(East, 0)  ln2 -> (West, 0) loc3
*/

/* The following layout is the default minimal map for theses tests

   +------+--------+
   | 1 (1)|-(2)  2 |  
   +------+--------+
*/

async function loadDefaultMap(arena, gid) {
  const chaintrap = await _chaintrap;

  const locations = [
    new chaintrap.RawLocation("0x01", "",           "",           "",               "0x0001"),
    new chaintrap.RawLocation("0x01", "",           "0x00020005", "0x000600070008", "0x0003"),
    new chaintrap.RawLocation("0x01", "",           "0x0004",     "",               ""),
    new chaintrap.RawLocation("0x01", "",           "",           "",               "0x0009"),
    new chaintrap.RawLocation("0x01", "0x000a",     "",           "",               "0x000b"),
    new chaintrap.RawLocation("0x01", "0x000d000e", "0x000c",     "",               ""),
  ];

  let tx = await arena.loadLocations(gid, locations);
  let r = await tx.wait();
  expect(r.status).to.equal(1);

  const exits = [
    // room 1
    new chaintrap.RawExit("0x00010001"), // e1
    // room 2
    new chaintrap.RawExit("0x00010002"), // e2
    new chaintrap.RawExit("0x00020002"), // e3
    // room 3
    new chaintrap.RawExit("0x00020003"), // e4
    // room 2
    new chaintrap.RawExit("0x00030002"), // e5
    new chaintrap.RawExit("0x00040002"), // e6
    new chaintrap.RawExit("0x00050002"), // e7
    new chaintrap.RawExit("0x00060002"), // e8
    // room 4
    new chaintrap.RawExit("0x00030004"), // e9
    // room 5
    new chaintrap.RawExit("0x00040005"), // e10
    new chaintrap.RawExit("0x00070005"), // e11
    // room 6
    new chaintrap.RawExit("0x00070006"), // e12
    new chaintrap.RawExit("0x00050006"), // e13
    new chaintrap.RawExit("0x00060006"), // e14
  ];
  tx = await arena.loadExits(gid, exits);
  r = await tx.wait();
  expect(r.status).to.equal(1);

  const links = [
    new chaintrap.RawLink("0x0100010002"), // (1)-(2) ln1
    new chaintrap.RawLink("0x0100030004"), // (3)-(4) ln2
    new chaintrap.RawLink("0x0100050009"), // (5)-(9) ln3
    new chaintrap.RawLink("0x010006000a"), // (6)-(10) ln4
    new chaintrap.RawLink("0x010007000d"), // (7)-(13) ln5
    new chaintrap.RawLink("0x010008000e"), // (8)-(14) ln6
    new chaintrap.RawLink("0x01000b000c") // (11)-(12) ln7
  ];

  tx = await arena.loadLinks(gid, links);
  r = await tx.wait();
  expect(r.status).to.equal(1);
}

async function createGame() {

    const chaintrap = await _chaintrap;

    const Arena = await ethers.getContractFactory("Arena");
    let arena = await Arena.deploy();
    await arena.deployed();

    const [master] = await ethers.getSigners();
    arena = arena.connect(master)
    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    const gid = r.events[1].args.gid;
    return [arena, gid];
}

class Game {

  static async createDefault(master) {
    const chaintrap = await _chaintrap;

    const Arena = await ethers.getContractFactory("Arena");
    let arena = await Arena.deploy();
    await arena.deployed();

    arena = arena.connect(master);

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    const gid = r.events[1].args.gid;
    const tid = r.events[1].args.tid;

    return new Game(new chaintrap.Game(arena, gid, tid));
  }

  static async connectPlayer(game, player) {
    const chaintrap = await _chaintrap;
    return new Game(new chaintrap.Game(game.g.arena.connect(player), game.g.gid, game.g.tid));
  }

  constructor(game) {

    // Note: game.arena should be connected to the appopriate signer. commitExitUse
    // will (eventually) revert if its not invoked by the game creator.

    this.g = game;
  }

  tokenLocation(blocknumber, loc) {
    return this.g.tokenize(blocknumber, loc);
  }

  transcriptionLocation(blocknumber, loc) {
    return this.g.transcriptionLocation(blocknumber, loc);
  }

  async loadDefaultMap() {
    return await loadDefaultMap(this.g.arena, this.g.gid, this.g.tid);
  }

  /**
   * dev game setup creation & player signup
   */

  async joinGame(profile) {
    return this.g.joinGame(profile);
  }

  async setStartLocation(player, startToken, sceneblob) {
    return this.g.setStartLocation(player, startToken, sceneblob);
  }

  /**
   * 
   * game phase transitions
   * @returns 
   */

  async startGame() {
    return this.g.startGame();
  }

  async completeGame() {
    return this.g.completeGame();
  }

  /**
   * game progression
   */

  async commitExitUse(side, egressIndex)  {
    return this.g.commitExitUse(side, egressIndex);
  }

  async allowExitUse(eid, token, scene, side, ingressIndex, halt) {
    return this.g.allowExitUse(eid, token, scene, side, ingressIndex, halt);
  }

  /**
   * game transcript checking & location loading
   */

  async loadTranscriptLocations(locations) {
    return this.g.loadTranscriptLocations(locations);
  }

  async playTranscript() {
    return this.g.playTranscript();
  }
}

describe("Transcript", function () {

  it("Should load single location without reverting", async function () {

    const chaintrap = await _chaintrap;

    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    const gid = r.events[1].args.gid;

    tx = await arena.startGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await arena.completeGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    const locations = [
      new chaintrap.RawLocation("0x01", [], [], [], "0x0001")
    ];

    tx = await arena.loadLocations(gid, locations);
    r = await tx.wait();
    expect(r.status).to.equal(1);
  });

  it("Should load default map", async function () {

    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    const gid = r.events[1].args.gid;
    const tid = r.events[1].args.tid;

    tx = await arena.startGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await arena.completeGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    await loadDefaultMap(arena, gid, tid);
  });

  it ("Should visit all rooms on the default map", async function() {

    const chaintrap = await _chaintrap;

    const [master, player] = await ethers.getSigners();

    const gm = await Game.createDefault(master);
    const gp = await Game.connectPlayer(gm, player);

    /*
    +------+---------------------------+-----+
    | 1 (1)|-(2)  2                (3)-|-(4) |  
    +-+----+                           |   3 |
      |(9)-|-(5)                       +-----+
      | 4  |(6)              (7)   (8) |
      +----+-|-------+--------|-----|--+
      | 5  (10) (11)-|-(12) 6(13) (14) |
      +--------------+-----------------+

    (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
    (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
    (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
    (6,10)  exitUse(South, 0) ln4 -> (North,0) loc5
    (11,12) exitUse(East, 0)  ln7 -> (West, 0) loc6
    (7,13)  exitUse(North, 0) ln5 -> (South,2) loc2
    (8,14)  exitUse(South, 2) ln6 -> (North,1) loc6
    (8,14)  exitUse(North, 1) ln2 -> (South,2) loc2
    (3,4)   exitUse(East, 0)  ln2 -> (West, 0) loc3
    */
    let blocknumber = 1;
    const locationTE = (loc) => {
      const te = gp.transcriptionLocation(blocknumber, loc);
      blocknumber += 1;
      return te;
    }

    const commitAndAllowExitUse = async (egress, egressExit, ingress, ingressExit, locationToken) => {
      // player commits
      const eid = await gp.commitExitUse(egress, egressExit);

      // gm allows
      await gm.allowExitUse(eid, locationToken, [],ingress, ingressExit);
      return eid;
    }

    const locations = [];
    const ids = [];

    const { NORTH, WEST, SOUTH, EAST } = chaintrap.locationSides();

    currentLocationToken = () => {
      return locations[locations.length-1].token;
    }

    // start position
    locations.push(locationTE(1));

    await gp.joinGame("");
    await gm.setStartLocation(player.address, locations[0].token, []);
    await gm.startGame();

    // In commitAndAllowExit use the player commit to an exit use that takes
    // them to 'currentLocationToken'. The gm allows that.

    // (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
    locations.push(locationTE(2));
    ids.push(await commitAndAllowExitUse(EAST, 0, WEST, 0, currentLocationToken()));

    // (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
    locations.push(locationTE(4));
    ids.push(await commitAndAllowExitUse(WEST, 1, EAST, 0, currentLocationToken()));

    // (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
    locations.push(locationTE(2));
    ids.push(await commitAndAllowExitUse(EAST, 0, WEST, 1, currentLocationToken()));

    // (6,10)  exitUse(SOUTH, 0) ln4 -> (NORTH,0) loc5
    locations.push(locationTE(5));
    ids.push(await commitAndAllowExitUse(SOUTH, 0, NORTH, 1, currentLocationToken()));

    // (11,12) exitUse(EAST, 0)  ln7 -> (West, 0) loc6
    locations.push(locationTE(6));
    ids.push(await commitAndAllowExitUse(EAST, 0, WEST, 0, currentLocationToken()));

    // (7,13)  exitUse(NORTH, 0) ln5 -> (SOUTH,2) loc2
    locations.push(locationTE(2));
    ids.push(await commitAndAllowExitUse(NORTH, 0, SOUTH, 2, currentLocationToken()));

    // (8,14)  exitUse(SOUTH, 2) ln6 -> (NORTH,1) loc6
    locations.push(locationTE(6));
    ids.push(await commitAndAllowExitUse(SOUTH, 2, NORTH, 1, currentLocationToken()));

    // (8,14)  exitUse(NORTH, 1) ln2 -> (SOUTH,2) loc2
    locations.push(locationTE(2));
    ids.push(await commitAndAllowExitUse(NORTH, 1, SOUTH, 2, currentLocationToken()));

    // (3,4)   exitUse(EAST, 0)  ln2 -> (West, 0) loc3
    locations.push(locationTE(3));
    ids.push(await commitAndAllowExitUse(EAST, 0, WEST, 0, currentLocationToken()));

    await gm.completeGame();

    await gm.loadDefaultMap();
    await gm.loadTranscriptLocations(locations);
    await gm.playTranscript();
  });

  it ("Should play single move game", async function () {
    const chaintrap = await _chaintrap;
    const sides = await locationSides();
    const [arena, gid, tid] = await createGame(2, "");

    const [master, player] = await ethers.getSigners();
    const am = arena.connect(master)
    const ap = arena.connect(player)

    tx = await ap.joinGame(gid, "0x");
    r = await tx.wait();
    expect(r.status).to.equal(1);

    let blocknumber = 1;
    const startLoc = 1;
    const startToken = chaintrap.TranscriptLocation.tokenize(blocknumber, startLoc);

    tx = await am.setStartLocation(gid, player.address, startToken, []);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await am.startGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    let commit = {side:sides.EAST, egressIndex: 0};
    tx = await ap.commitExitUse(gid, commit);
    r = await tx.wait();
    let eid = r.events[0].args.eid;

    blocknumber += 1;
    const loc = 2;
    const token = chaintrap.TranscriptLocation.tokenize(blocknumber, loc);

    let outcome = {location: token, sceneblob: [], side:sides.WEST, ingressIndex: 1, halt: false};
    tx = await am.allowExitUse(gid, eid, outcome);
    r = await tx.wait();

    tx = await am.completeGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);


    // Now that we have the play session transcript, reveal the map
    await loadDefaultMap(arena, gid);

    // provide the contract 
    const locations = [
      new chaintrap.TranscriptLocation(startToken, 1, startLoc),
      new chaintrap.TranscriptLocation(token, 2, loc)
    ];

    tx = await arena.loadTranscriptLocations(gid, locations);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await arena.playTranscript(gid, 0, 0);
    r = await tx.wait();
    expect(r.status).to.equal(1);
  });

  it("Should commit a single ExitUse", async function () {

    const sides = await locationSides();

    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    let tx = await arena.createGame(2, "");
    let r = await tx.wait();
    let gid = r.events[1].args.gid;
    let tid = r.events[1].args.tid;
    expect(gid).to.equal(1);
    expect(tid).to.equal(1);

    const [master, player] = await ethers.getSigners();
    const am = arena.connect(master)
    const ap = arena.connect(player)

    tx = await ap.joinGame(gid, "0x");
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await am.setStartLocation(gid, player.address, keccak256("0x01"), []);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await am.startGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    let commit = {side:sides.EAST, egressIndex: 0};
    tx = await ap.commitExitUse(gid, commit);
    r = await tx.wait();
    expect(r.status).to.equal(1);
    expect(r.events[0].event).to.equal("UseExit");
    expect(r.events[0].args.eid).to.equal(1);
    expect(r.events[0].args.gid).to.equal(1);
    expect(r.events[0].args.player).to.equal(player.address);
    expect(r.events[0].args[3].side).to.equal(sides.EAST);
    expect(r.events[0].args[3].egressIndex).to.equal(0);
  });
  it("Should commit and allow a single ExitUse", async function () {

    const sides = await locationSides();

    const Arena = await ethers.getContractFactory("Arena");
    const arena = await Arena.deploy();
    await arena.deployed();

    const [master, player] = await ethers.getSigners();
    const am = arena.connect(master)
    const ap = arena.connect(player)

    let tx = await am.createGame(2, "");
    let r = await tx.wait();
    let gid = r.events[1].args.gid;
    let tid = r.events[1].args.tid;
    expect(gid).to.equal(1);
    expect(tid).to.equal(1);

    tx = await ap.joinGame(gid, "0x");
    r = await tx.wait();
    expect(r.status).to.equal(1);

    tx = await am.startGame(gid);
    r = await tx.wait();
    expect(r.status).to.equal(1);

    let commit = {side:sides.EAST, egressIndex: 0};
    tx = await ap.commitExitUse(gid, commit);
    r = await tx.wait();
    let eid = r.events[0].args.eid;
    expect(eid).to.equal(1);

    let loctok = ethers.utils.hexlify(ethers.utils.randomBytes(32));

    let outcome = {location: loctok, sceneblob: [], side:sides.WEST, ingressIndex: 1, halt: false};
    tx = await am.allowExitUse(gid, eid, outcome).then((result)=>{
        return result;
    }, (error)=>{
        console.log('Error', error);
    });
    r = await tx.wait();

    expect(r.events[0].event).to.equal("ExitUsed");
    expect(r.events[0].args.eid).to.equal(1);
    expect(r.events[0].args.player).to.equal(player.address);
    expect(r.events[0].args[3].side).to.equal(sides.WEST);
    expect(r.events[0].args[3].ingressIndex).to.equal(1);
  });

});



