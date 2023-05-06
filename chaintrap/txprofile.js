import { BigNumber } from "ethers";
import { pushFIFO } from "./fifo.js";

export class TXProfiler {
  constructor(movingAverageWindow = 10, optional) {
    this.movingAverageWindow = movingAverageWindow;
    this.updated = optional?.updated;
    this.now = () => Date.now();
    this.reset();
  }

  reset() {
    this.order = 1;
    this.pending = {};
    this.fifo = [];
  }

  async txissue(method, ...args) {
    const called = this.now();
    const order = this.order;
    this.order += 1;

    const tx = await method(...args);

    this.pending[tx.hash] = { order, tx, called, issued: this.now() };
    return tx;
  }

  async txwait(tx) {
    const r = await tx.wait();

    const profiled = this.pending[r.transactionHash];
    delete this.pending[r.transactionHash];
    profiled.complete = this.now();
    profiled.status = r.status == 1;
    profiled.gasUsed = r.gasUsed;
    profiled.gasPrice = r.effectiveGasPrice;

    pushFIFO(this.fifo, this.movingAverageWindow, profiled);

    if (this.updated) this.updated(this);

    return r;
  }

  latency() {
    let sum = 0;
    if (!this.fifo.length) return 0;

    this.fifo.forEach((p) => (sum += p.complete - p.called));
    return sum / this.fifo.length;
  }

  gas() {
    if (!this.fifo.length) return 0;

    let sum = BigNumber.from(0);
    this.fifo.forEach((p) => {
      if (!p.gasUsed) return;
      sum = sum.add(p.gasUsed);
    });
    return sum.div(this.fifo.length).toNumber();
  }
  price() {
    if (!this.fifo.length) return 0;

    let sum = BigNumber.from(0);

    this.fifo.forEach((p) => {
      if (p.gasPrice) sum = sum.add(p.gasPrice);
    });

    return sum.div(this.fifo.length).toNumber();
  }

  lastSample() {
    if (!this.fifo.length) return;
    return this.fifo[this.fifo.length - 1];
  }

  lastLatency() {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.complete - p.called;
  }

  lastGas() {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.gasUsed?.toNumber() ?? 0;
  }

  lastPrice() {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.gasPrice?.toNumber() ?? 0;
  }
}
