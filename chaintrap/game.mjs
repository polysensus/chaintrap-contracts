import { ethers } from "ethers";
import { TranscriptLocation } from "./transcript.mjs";
const arrayify = ethers.utils.arrayify;

export class Game {
  constructor(arena, gid, tid, optional = {}) {
    // Note: arena should be connected to the appopriate signer. commitExitUse
    // will (eventually) revert if its not invoked by the game creator.
    this.arena = arena;
    this.gid = gid;
    this.tid = tid;

    this._txissue = optional?.txissue
      ? optional.txissue
      : async (method, ...args) => {
          return method(...args);
        };
    this._txwait = optional?.txwait
      ? optional.txwait
      : async (tx) => {
          return tx.wait();
        };
  }

  tokenLocation(blocknumber, loc) {
    return TranscriptLocation.tokenize(blocknumber, loc);
  }

  transcriptionLocation(blocknumber, loc) {
    return new TranscriptLocation(
      this.tokenLocation(blocknumber, loc),
      blocknumber,
      loc
    );
  }

  _checkStatus(r, msg) {
    if (r.status != 1) {
      throw Error(msg);
    }
  }

  /**
   * game setup
   */

  async joinGame(profile) {
    profile = profile || "0x";
    if (profile === "") profile = "0x";

    const tx = await this._txissue(this.arena.joinGame, this.gid, profile);
    const r = await this._txwait(tx);
    this._checkStatus(r, "joinGame reverted");
    return r;
  }

  async setStartLocation(player, startToken, sceneblob) {
    const tx = await this._txissue(
      this.arena.setStartLocation,
      this.gid,
      player,
      startToken,
      sceneblob
    );
    const r = await this._txwait(tx);
    this._checkStatus(r, "setStartLocation reverted");
    return r;
  }

  async playerCount() {
    const count = await this.arena.playerCount(this.gid);
    return count;
  }

  async playerByIndex(i) {
    return await this.arena["player(uint256,uint8)"](this.gid, i);
  }

  async playerByAddress(addr) {
    return await this.arena["player(uint256,address)"](this.gid, addr);
  }

  /**
   * game phases
   */

  async startGame() {
    const tx = await this._txissue(this.arena.startGame, this.gid);
    const r = await this._txwait(tx);
    this._checkStatus(r, "start reverted");
    return r;
  }

  async completeGame() {
    const tx = await this._txissue(this.arena.completeGame, this.gid);
    const r = await this._txwait(tx);
    this._checkStatus(r, "complete reverted");
    return r;
  }

  /**
   * game progression
   */

  async commitExitUse(side, egressIndex) {
    let commit = { side: side, egressIndex: egressIndex };

    const tx = await this._txissue(this.arena.commitExitUse, this.gid, commit);
    const r = await this._txwait(tx);
    this._checkStatus(r, "commitExitUse reverted");
    console.log(JSON.stringify(r));
    return r.events[0].args.eid;
  }

  async allowExitUse(eid, token, scene, side, ingressIndex, halt) {
    const outcome = {
      location: token,
      sceneblob: scene,
      side: side,
      ingressIndex: ingressIndex,
      halt: halt,
    };
    const tx = await this._txissue(
      this.arena.allowExitUse,
      this.gid,
      eid,
      outcome
    );
    const r = await this._txwait(tx);
    this._checkStatus(r, "allowExitUse reverted");
    return r;
  }

  /**
   * map loading and transcript checking
   */

  async loadTranscriptLocations(locations) {
    const tx = await this._txissue(
      this.arena.loadTranscriptLocations,
      this.gid,
      locations
    );
    const r = await this._txwait(tx);
    this._checkStatus(r, "loadTranscriptLocations reverted");
    return r;
  }

  async playTranscript() {
    const tx = await this._txissue(this.arena.playTranscript, this.gid, 0, 0);
    const r = await this._txwait(tx);
    this._checkStatus(r, "playTranscript reverted");
    return r;
  }
}
