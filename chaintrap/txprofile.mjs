import { pushFIFO } from "./fifo.mjs"

export class TXProfiler {
  constructor (movingAverageWindow=10, optional) {
    this.order = 1
    this.pending = {}
    this.movingAverageWindow = movingAverageWindow
    this.fifo = []
    this.updated = optional?.updated

    this.now = () => Date.now()
  }

  async txissue(method, ...args) {
    const called = this.now()
    const order = this.order
    this.order += 1

    const tx = await method(... args)

    this.pending[tx.hash] = {order, tx, called, issued: this.now()}
    return tx
  }

  async txwait(tx) {
    const r = await tx.wait()

    const profiled = this.pending[r.transactionHash]
    delete this.pending[r.transactionHash]
    profiled.complete = this.now()
    profiled.status = r.status == 1
    profiled.gasUsed = r.gasUsed
    profiled.gasPrice = r.effectiveGasPrice

    pushFIFO(this.fifo, this.movingAverageWindow, profiled)

    if (this.updated) this.updated(this)

    return r
  }

  latency() {
    let sum = 0
    if (!this.fifo.length) return 0

    this.fifo.forEach(p => sum += (p.complete - p.called))
    return sum / this.fifo.length
  }

  lastLatency() {
    if (!this.fifo.length) return 0
    const p = this.fifo[0]
    return p.complete - p.called
  }

  gas() {
    let sum = 0
    if (!this.fifo.length) return 0

    this.fifo.forEach(p => {
      if (!p.gasUsed) return
      sum += p.gasUsed
    })
    return sum / this.fifo.length
  }
  price () {
    let sum = 0

    if (!this.fifo.length) return 0

    this.fifo.forEach(p => {
      if (p.gasPrice) sum += p.gasPrice
    })

    return sum / this.fifo.length
  }
}