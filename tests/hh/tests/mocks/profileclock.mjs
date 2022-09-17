export class MockProfileClock {
  constructor({readings, tick, start}={readings:undefined, tick:1, start:0}) {
    this.readings = readings
    this.tick = tick
    this.clock = start
    if (tick > 0) {
      this.tick = tick
    }
    if (this.readings){
      this.now = () => this.readings.shift()
    } else {
      this.now = () => {
        this.clock += this.tick
        return this.clock
      }
    }
  }
}