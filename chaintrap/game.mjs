import {ethers} from 'ethers';
import { TranscriptLocation } from './transcript.mjs';

export class Game {

  constructor(arena, gid, tid) {

    // Note: arena should be connected to the appopriate signer. commitExitUse
    // will (eventually) revert if its not invoked by the game creator.
    this.arena = arena;
    this.gid = gid;
    this.tid = tid;
  }

  tokenLocation(blocknumber, loc) {
    return TranscriptLocation.tokenize(blocknumber, loc);
  }

  transcriptionLocation(blocknumber, loc) {
    return new TranscriptLocation(this.tokenLocation(blocknumber, loc), blocknumber, loc);
  }

  _checkStatus(r, msg) {
    if (r.status != 1) {
      throw Error(msg);
    }
  }

  /**
   * game setup
   */

  async joinGame() {
    const tx = await this.arena.joinGame(this.gid);
    const r = await tx.wait();
    this._checkStatus(r, "joinGame reverted");
  }

  async setStartLocation(player, startToken, sceneblob) {
    const tx = await this.arena.setStartLocation(this.gid, player, startToken, sceneblob);
    const r = await tx.wait();
    this._checkStatus(r, "setStartLocation reverted");
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
    const tx = await this.arena.startGame(this.gid);
    const r = await tx.wait();
    this._checkStatus(r, "start reverted");
  }

  async completeGame() {
    const tx = await this.arena.completeGame(this.gid);
    const r = await tx.wait();
    this._checkStatus(r, "complete reverted");
  }

  /**
   * game progression
   */

  async commitExitUse(side, egressIndex)  {

    let commit = {side:side, egressIndex: egressIndex};

    const signer = await this.arena.signer.getAddress();
    console.log(`commitExitUse gid=${this.gid}, signer=${signer}, commit=${JSON.stringify(commit)}`);

    const tx = await this.arena.commitExitUse(this.gid, signer, commit);
    const r = await tx.wait();
    this._checkStatus(r, "commitExitUse reverted");
    console.log(JSON.stringify(r));
    return r.events[0].args.eid;
  }

  async allowExitUse(eid, token, scene, side, ingressIndex, halt) {

    const outcome = {location: token, sceneblob: scene, side:side, ingressIndex: ingressIndex, halt: halt};
    const tx = await this.arena.allowExitUse(this.gid, eid, outcome);
    const r = await tx.wait();
    this._checkStatus(r, "allowExitUse reverted");
  }

  /**
   * map loading and transcript checking 
   */

  async loadTranscriptLocations(locations) {
    const tx = await this.arena.loadTranscriptLocations(this.gid, locations);
    const r = await tx.wait();
    this._checkStatus(r, "loadTranscriptLocations reverted");
  }


  async playTranscript() {
    const tx = await this.arena.playTranscript(this.gid, 0, 0);
    const r = await tx.wait();
    this._checkStatus(r, "playTranscript reverted");
  }
}