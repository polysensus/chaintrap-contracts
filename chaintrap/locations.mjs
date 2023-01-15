import {ethers} from 'ethers';
import { locationSides } from './chaintrap.mjs';
const bytes = ethers.utils.arrayify;

export class Kind {
    static Undefined = 0;
    static Room = 1;
    static Intersection = 2;
    static Corridor = 3;
}

export class SideKind {
    static Undefined = 0;
    static North = 1;
    static West = 2;
    static South = 3;
    static East = 4;
    static Invalid = 5;
}

export class Locations {
    static Kind = Kind;
    static SideKind = SideKind;
}

export class Location {

    static fromHex(kind, north, west, south, east) {

        const hexsides = [north, west, south, east];
        const sides = [[], [], [], []];
        for (var i = 0; i < hexsides.length; i++) {
            if (hexsides[i].length === 0) continue;

            var b = ethers.utils.arrayify(hexsides[i])
            for (var j = 0; j < b.length >> 1; j++) {
                var exitID = b[j*2+0] << 8 | b[j*2+1];
                sides[i].push(exitID);
            }
        }
        return new Location(parseInt(kind, 16), sides);
    }

    constructor(kind, sides) {
        this.kind = kind;
        if (!sides) sides = [[], [], [], []];
        this.sides = sides;
    }
    native() {
        return [this.kind, this.sides];
    }
}

class RawLocation {

    constructor(kind, north, west, south, east) {

        this.sides = [null, null, null, null, null];

        let i = 0;
        this.sides[i] = kind;

        const setbytes = (i, value) => {

            this.sides[i] = value;
            if (Array.isArray(value)) {
                return;
            }

            if (value.length == 0 || value == "0x") {
                this.sides[i] = []
            } else{
                this.sides[i] = bytes(value);
            }
        }

        setbytes(0, kind);
        // because SideKind.Undefined is 0, North starts at 1
        setbytes(SideKind.North, north);
        setbytes(SideKind.West, west);
        setbytes(SideKind.South, south);
        setbytes(SideKind.East, east);
    }
}
