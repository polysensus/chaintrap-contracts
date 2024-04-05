import { BigNumber } from "ethers";
import { pushFIFO } from "./fifo";

interface PendingTransaction {
  order: number;
  tx: any;
  called: number;
  issued: number;
  complete?: number;
  status?: boolean;
  gasUsed?: number;
  gasPrice?: BigNumber;
}

type UpdateCallback = (profiler: TXProfiler) => void;

export class TXProfiler {
  private movingAverageWindow: number;
  private updated?: UpdateCallback;
  private now: () => number;
  private order: number;
  private pending: Record<string, PendingTransaction>;
  private fifo: PendingTransaction[];

  constructor(
    movingAverageWindow: number = 10,
    optional?: { updated?: UpdateCallback }
  ) {
    this.movingAverageWindow = movingAverageWindow;
    this.updated = optional?.updated;
    this.now = () => Date.now();
    this.reset();
  }

  reset(): void {
    this.order = 1;
    this.pending = {};
    this.fifo = [];
  }

  async txissue(
    method: (...args: any[]) => Promise<any>,
    ...args: any[]
  ): Promise<any> {
    const called = this.now();
    const order = this.order;
    this.order += 1;

    const tx = await method(...args);

    this.pending[tx.hash] = { order, tx, called, issued: this.now() };
    return tx;
  }

  async txwait(tx: any): Promise<any> {
    const r = await tx.wait();

    const profiled = this.pending[r.transactionHash];
    delete this.pending[r.transactionHash];
    profiled.complete = this.now();
    profiled.status = r.status === 1;
    profiled.gasUsed = r.gasUsed;
    profiled.gasPrice = r.effectiveGasPrice;

    pushFIFO(this.fifo, this.movingAverageWindow, profiled);

    if (this.updated) this.updated(this);

    return r;
  }

  latency(): number {
    let sum = 0;
    if (!this.fifo.length) return 0;

    this.fifo.forEach((p) => (sum += p.complete - p.called));
    return sum / this.fifo.length;
  }

  gas(): number {
    if (!this.fifo.length) return 0;

    let sum = BigNumber.from(0);
    this.fifo.forEach((p) => {
      if (!p.gasUsed) return;
      sum = sum.add(p.gasUsed);
    });
    return sum.div(this.fifo.length).toNumber();
  }

  price(): number {
    if (!this.fifo.length) return 0;

    let sum = BigNumber.from(0);
    this.fifo.forEach((p) => {
      if (p.gasPrice) sum = sum.add(p.gasPrice);
    });
    return sum.div(this.fifo.length).toNumber();
  }

  lastSample(): PendingTransaction | undefined {
    if (!this.fifo.length) return undefined;
    return this.fifo[this.fifo.length - 1];
  }

  lastLatency(): number {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.complete - p.called;
  }

  lastGas(): number {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.gasUsed?.toNumber() ?? 0;
  }

  lastPrice(): number {
    if (!this.fifo.length) return 0;
    const p = this.fifo[this.fifo.length - 1];
    return p.gasPrice?.toNumber() ?? 0;
  }
}
