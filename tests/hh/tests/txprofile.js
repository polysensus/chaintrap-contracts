import chai from "chai";
const { expect } = chai;
import { TXProfiler } from "../../../chaintrap/txprofile.js";

import { MockProfileMethod } from "./mocks/profilemethod.js";
import { MockProfileClock } from "./mocks/profileclock.js";

describe("TXProfile", function () {
  it("Should average 1 second", async function () {
    const tp = new TXProfiler(3);
    tp.now = new MockProfileClock().now;
    const contract = new MockProfileMethod();

    for (let i = 0; i < 5; i++) {
      const tx = await tp.txissue((...args) => contract.method(...args));
      await tp.txwait(tx);
      if (i == 0) continue;

      const latency = tp.latency();
      const gas = tp.gas();
      const price = tp.price();

      expect(gas).to.equal(1);
      expect(price).to.equal(1);
      expect(latency).to.equal(2);
    }
  });
});
