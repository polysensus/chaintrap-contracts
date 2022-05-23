import {ethers} from 'ethers';
const bytes = ethers.utils.arrayify;

class Kind {
    static Undefined = 0;
    static Room = 1;
    static Intersection = 2;
    static Corridor = 3;
}

class SideKind {
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

export class RawLocation {

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
