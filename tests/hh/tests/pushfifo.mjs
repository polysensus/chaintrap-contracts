import chai from 'chai'
const { expect } = chai
import { pushFIFO } from '../../../chaintrap/fifo.mjs'

describe("pushFIFO", function () {
  it("Should add one to empty fifo", async function () {
    const fifo = []
    pushFIFO(fifo, 10, 1)
    expect(fifo.length).to.equal(1)
  })

  it("Should replace part fifo", async function () {
    const fifo = [0, 1, 2]
    pushFIFO(fifo, 3, 3, 4)
    expect(fifo.length).to.equal(3)
    expect(fifo).to.eql([2,3,4])
  })

  it("Should replace exactly all fifo", async function () {
    const fifo = [0, 1, 2]
    pushFIFO(fifo, 3, 3, 4, 5)
    expect(fifo.length).to.equal(3)
    expect(fifo).to.eql([3,4, 5])
  })

  it("Should replace all with tail capacity items", async function () {
    const fifo = [0, 1, 2]
    pushFIFO(fifo, 3, 3, 4, 5, 6, 7)
    expect(fifo.length).to.equal(3)
    expect(fifo).to.eql([5, 6, 7])
  })

  it("Should correct overfilled fifo", async function () {
    const fifo = [0, 1, 2, 4]
    pushFIFO(fifo, 3, 5, 6)
    expect(fifo.length).to.equal(3)
    expect(fifo).to.eql([4, 5, 6])
  })
});