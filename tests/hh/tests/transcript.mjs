import chai from 'chai'
const { expect } = chai
import hardhat from 'hardhat'
const { ethers } = hardhat
const bytes = ethers.utils.arrayify;
const keccak256 = ethers.utils.keccak256;
import { deployArena } from "./deploy.js";
import { createArenaProxy } from './arenaproxy.mjs'

import { Game, Location, Exit, Link, NORTH, WEST, SOUTH, EAST } from "../../../chaintrap/chaintrap.mjs";

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

  const locations = [
    Location.fromHex("0x01", "",           "",           "",               "0x0001").native(),
    Location.fromHex("0x01", "",           "0x00020005", "0x000600070008", "0x0003").native(),
    Location.fromHex("0x01", "",           "0x0004",     "",               "").native(),
    Location.fromHex("0x01", "",           "",           "",               "0x0009").native(),
    Location.fromHex("0x01", "0x000a",     "",           "",               "0x000b").native(),
    Location.fromHex("0x01", "0x000d000e", "0x000c",     "",               "").native(),
  ];

  let r = await receipt(arena.loadLocations, gid, locations);
  expect(r.status).to.equal(1);

  const exits = [
    // room 1
    Exit.fromHex("0x00010001").native(), // e1
    // room 2
    Exit.fromHex("0x00010002").native(), // e2
    Exit.fromHex("0x00020002").native(), // e3
    // room 3
    Exit.fromHex("0x00020003").native(), // e4
    // room 2
    Exit.fromHex("0x00030002").native(), // e5
    Exit.fromHex("0x00040002").native(), // e6
    Exit.fromHex("0x00050002").native(), // e7
    Exit.fromHex("0x00060002").native(), // e8
    // room 4
    Exit.fromHex("0x00030004").native(), // e9
    // room 5
    Exit.fromHex("0x00040005").native(), // e10
    Exit.fromHex("0x00070005").native(), // e11
    // room 6
    Exit.fromHex("0x00070006").native(), // e12
    Exit.fromHex("0x00050006").native(), // e13
    Exit.fromHex("0x00060006").native(), // e14
  ];

  r = await receipt(arena.loadExits, gid, exits);
  expect(r.status).to.equal(1);

  const links = [
    Link.fromHex("0x0100010002").native(), // (1)-(2) ln1
    Link.fromHex("0x0100030004").native(), // (3)-(4) ln2
    Link.fromHex("0x0100050009").native(), // (5)-(9) ln3
    Link.fromHex("0x010006000a").native(), // (6)-(10) ln4
    Link.fromHex("0x010007000d").native(), // (7)-(13) ln5
    Link.fromHex("0x010008000e").native(), // (8)-(14) ln6
    Link.fromHex("0x01000b000c").native() // (11)-(12) ln7
  ];

  r = await receipt(arena.loadLinks, gid, links);
  expect(r.status).to.equal(1);
}

function checkStatus(r, msg) {
  if (r.status != 1) {
    throw Error(msg || "transaction not successful")
  }
}

async function newGame(arena, maxPlayers) {
    let tx = await arena.createGame(maxPlayers, "")
    let r = await tx.wait()
    checkStatus(r)
    return [r.events[1].args.gid, r.events[1].args.tid]
}

async function receipt(method, ...args) {
  const tx = await method(...args);
  return tx.wait();
}


describe("Transcript", function () {

  let proxy;
  let arena;
  let masterSigner;
  let playerSigner;
  let master, player;

  before(async function () {
    proxy = await deployArena();
    const signers = await ethers.getSigners();
    [masterSigner, playerSigner] = signers;
    arena = createArenaProxy(proxy.address, masterSigner);
    master = arena;
    player = createArenaProxy(proxy.address, playerSigner);
  });

  it("Should load single location without reverting", async function () {

    let r = await receipt(arena.createGame, 2, "");
    const gid = r.events[1].args.gid;

    r = await receipt(arena.startGame, gid);
    expect(r.status).to.equal(1);

    r = await receipt(arena.completeGame, gid);
    expect(r.status).to.equal(1);

    const locations = [
      Location.fromHex("0x01", "", "", "", "0x0001").native()
    ];

    r = await receipt(arena.loadLocations, gid, locations);

    expect(r.status).to.equal(1);
  });

  it("Should load default map", async function () {

    let r = await receipt(arena.createGame, 2, "");
    expect(r.status).to.equal(1);
    const gid = r.events[1].args.gid;
    const tid = r.events[1].args.tid;

    r = await receipt(arena.startGame, gid);
    expect(r.status).to.equal(1);

    r = await receipt(arena.completeGame, gid);
    expect(r.status).to.equal(1);

    await loadDefaultMap(arena, gid, tid);
  });

  it ("Should visit all rooms on the default map", async function() {

    let r = await receipt(arena.createGame, 2, "");
    expect(r.status).to.equal(1);
    const gid = r.events[1].args.gid;
    const tid = r.events[1].args.tid;

    const gm = new Game(master, gid, tid);
    const gp = new Game(player, gid, tid);

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

    const currentLocationToken = () => {
      return locations[locations.length-1].token;
    }

    // start position
    locations.push(locationTE(1));

    await gp.joinGame("");
    await gm.setStartLocation(playerSigner.address, locations[0].token, []);
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

    await loadDefaultMap(gm.arena, gid);
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
    let gid = r.events[0].args.gid;
    let tid = r.events[0].args.tid;
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
    let gid = r.events[0].args.gid;
    let tid = r.events[0].args.tid;
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



