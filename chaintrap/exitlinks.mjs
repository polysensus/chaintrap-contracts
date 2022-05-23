import {ethers} from 'ethers';
const bytes = ethers.utils.arrayify;

class Kind {
    static Undefined = 0;
    static Door = 1;
    static Archway = 2;
    static Invalid = 3;
}

export class RawExit {

    constructor (linkloc) {
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

    constructor (kindexits) {
        if (Array.isArray(kindexits)) {
            this.kindexits = kindexits;
            return;
        }
        this.kindexits = bytes(kindexits);
    }
}