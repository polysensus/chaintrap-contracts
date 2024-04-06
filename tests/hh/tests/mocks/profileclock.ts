export class MockProfileClock {
  private readings: number[] | undefined;
  private tick: number;
  private clock: number;
  public now: () => number;

  constructor({
    readings,
    tick = 1,
    start = 0,
  }: {
    readings?: number[];
    tick?: number;
    start?: number;
  } = {}) {
    this.readings = readings;
    this.tick = tick;
    this.clock = start;

    if (this.tick > 0) {
      this.tick = tick;
    }

    if (this.readings) {
      this.now = () => {
        if (this.readings) {
          const value = this.readings.shift();
          if (value === undefined) {
            throw new Error("Readings array is empty");
          }
          return value;
        } else {
          throw new Error("Readings array is undefined");
        }
      };
    } else {
      this.now = () => {
        this.clock += this.tick;
        return this.clock;
      };
    }
  }
}
