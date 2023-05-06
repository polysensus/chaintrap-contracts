import { ethers } from "ethers";
const bytes = ethers.utils.arrayify;

class Kind {
  static Undefined = 0;
  static Door = 1;
  static Archway = 2;
  static Invalid = 3;
}

function be16ToNumber(bytes, start = 0) {
  if (bytes.length - start < 2)
    throw Error(
      `conversion from bytes to 16 bit number requires 2 bytes. Got start=${start} and length ${bytes.length}`
    );
  return (bytes[start + 0] << 1) | bytes[start + 1];
}

export class Exit {
  static fromHex(linkloc) {
    var b = bytes(linkloc);
    if (b.length !== 4)
      throw new Error(`linkloc must be 4 hex bytes, not ${linkloc.length}`);

    const link = be16ToNumber(b);
    const loc = be16ToNumber(b, 2);
    return new Exit(link, loc);
  }

  constructor(link, loc) {
    this.link = link;
    this.loc = loc;
  }

  native() {
    return [this.link, this.loc];
  }
}

export class Link {
  static fromHex(hexlink) {
    const b = bytes(hexlink);
    return new Link(b[0], [be16ToNumber(b, 1), be16ToNumber(b, 1 + 2)]);
  }
  constructor(kind, exits) {
    this.kind = kind;
    this.exits = exits;
    this.key = 0;
    this.autoclose = false;
    this._locked = false;
    this._open = false;
  }
  native() {
    return [
      this.kind,
      this.exits,
      this.key,
      this.autoclose,
      this._locked,
      this._open,
    ];
  }
}

export class RawExit {
  constructor(linkloc) {
    if (Array.isArray(linkloc)) {
      this.linkloc = linkloc;
      return;
    }
    this.linkloc = bytes(linkloc);
  }
}

export class Links {
  static Kind = Kind;
}

export class RawLink {
  constructor(kindexits) {
    if (Array.isArray(kindexits)) {
      this.kindexits = kindexits;
      return;
    }
    this.kindexits = bytes(kindexits);
  }
}
