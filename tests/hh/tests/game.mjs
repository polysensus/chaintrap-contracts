// const { expect } = require("chai")
// const { ethers } = require("hardhat")
import chai from 'chai'
const { expect } = chai
import hre from 'hardhat'
const { ethers } = hre
import deploypkg from "./deploy.js";
const { deployArenaFixture } = deploypkg;

import { MockProfileClock } from './mocks/profileclock.mjs'
import { createArenaProxy } from './arenaproxy.mjs'

import { Game } from '../../../chaintrap/game.mjs'
import { TXProfiler } from '../../../chaintrap/txprofile.mjs'

import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';


/* The following layout is the default map for theses tests

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

        RawLocation[] memory locations = new RawLocation[](6);

        locations[0].sides = [bytes(hex"01"), hex"", hex"", hex"", hex"0001"];
        locations[1].sides = [bytes(hex"01"), hex"", hex"00020005", hex"000600070008", hex"0003"];
        locations[2].sides = [bytes(hex"01"), hex"", hex"0004", hex"", hex""];
        locations[3].sides = [bytes(hex"01"), hex"", hex"", hex"", hex"0009"];
        locations[4].sides = [bytes(hex"01"), hex"000a", hex"", hex"", hex"000b"];
        locations[5].sides = [bytes(hex"01"), hex"000d000e", hex"000c", hex"", hex""];
            
        f.load(locations);

        RawExit[] memory exits = new RawExit[](14);
        // room 1
        exits[0] = RawExit(hex"00010001"); // e1
        // room 2
        exits[1] = RawExit(hex"00010002"); // e2
        exits[2] = RawExit(hex"00020002"); // e3
        // room 3
        exits[3] = RawExit(hex"00020003"); // e4
        // room 2
        exits[4] = RawExit(hex"00030002"); // e5
        exits[5] = RawExit(hex"00040002"); // e6
        exits[6] = RawExit(hex"00050002"); // e7
        exits[7] = RawExit(hex"00060002"); // e8
        // room 4
        exits[8] = RawExit(hex"00030004"); // e9
        // room 5
        exits[9] = RawExit(hex"00040005"); // e10
        exits[10] = RawExit(hex"00070005"); // e11
        // room 6
        exits[11] = RawExit(hex"00070006"); // e12
        exits[12] = RawExit(hex"00050006"); // e13
        exits[13] = RawExit(hex"00060006"); // e14

        f.load(exits);

        RawLink[] memory links = new RawLink[](7);
        links[0] = RawLink(hex"0100010002"); // (1)-(2) ln1
        links[1] = RawLink(hex"0100030004"); // (3)-(4) ln2
        links[2] = RawLink(hex"0100050009"); // (5)-(9) ln3
        links[3] = RawLink(hex"010006000a"); // (6)-(10) ln4
        links[4] = RawLink(hex"010007000d"); // (7)-(13) ln5
        links[5] = RawLink(hex"010008000e"); // (8)-(14) ln6
        links[6] = RawLink(hex"01000b000c"); // (11)-(12) ln7

        f.loadLinks(links);

*/

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


describe("Game", function () {
  let proxy;
  let owner;


  it("Should join new game", async function () {

    [proxy, owner] = await loadFixture(deployArenaFixture);
    const arena = createArenaProxy(proxy, owner);
    const [gid, tid] = await newGame(arena, 2)
    const g = new Game(arena, gid, tid)
    const r = await g.joinGame()
    expect(r.status).to.equal(1)
  })

  it("Should profile join new game", async function () {

    [proxy, owner] = await loadFixture(deployArenaFixture);
    const arena = createArenaProxy(proxy, owner);

    const tp = new TXProfiler(3)
    tp.now = new MockProfileClock().now

    const [gid, tid] = await newGame(arena, 2)
    const g = new Game(arena, gid, tid, {
      txissue: (...args) => tp.txissue(...args),
      txwait: (...args) => tp.txwait(...args)
    })
    const r = await g.joinGame()
    expect(r.status).to.eq(1)

    expect(tp.latency()).to.eq(2)
    const gas = tp.gas()
    const price = tp.price()
    console.log(gas, price)
    // expect(tp.gas()).to.eq(1)
    // expect(tp.price()).to.eq(1)
  })
});