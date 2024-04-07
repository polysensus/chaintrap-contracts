import { expect } from "chai";
import { pushFIFO } from "../../chaintrap/fifo";

describe("pushFIFO", function () {
  it("Should add one to empty fifo", function () {
    const fifo: number[] = [];
    pushFIFO(fifo, 10, 1);
    expect(fifo.length).to.equal(1);
  });

  it("Should replace part fifo", function () {
    const fifo: number[] = [0, 1, 2];
    pushFIFO(fifo, 3, 3, 4);
    expect(fifo.length).to.equal(3);
    expect(fifo).to.eql([2, 3, 4]);
  });

  it("Should replace exactly all fifo", function () {
    const fifo: number[] = [0, 1, 2];
    pushFIFO(fifo, 3, 3, 4, 5);
    expect(fifo.length).to.equal(3);
    expect(fifo).to.eql([3, 4, 5]);
  });

  it("Should replace all with tail capacity items", function () {
    const fifo: number[] = [0, 1, 2];
    pushFIFO(fifo, 3, 3, 4, 5, 6, 7);
    expect(fifo.length).to.equal(3);
    expect(fifo).to.eql([5, 6, 7]);
  });

  it("Should correct overfilled fifo", function () {
    const fifo: number[] = [0, 1, 2, 4];
    pushFIFO(fifo, 3, 5, 6);
    expect(fifo.length).to.equal(3);
    expect(fifo).to.eql([4, 5, 6]);
  });
});
