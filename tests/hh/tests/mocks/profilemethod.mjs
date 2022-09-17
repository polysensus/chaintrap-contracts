export class MockProfileMethod {
  constructor(receipts) {
    this.txhash = 1
    this.receipts = receipts
  }

  async method() {
    const tx = {
      txhash: this.txhash ++
    }
    return {
      ...tx,
      wait: async () => {
        const r = this.receipts ?
          this.receipts.shift() : {status: 1, gasUsed:1, effectiveGasPrice: 1}
        return {...tx, ...r}
      }
    }
  }
}