// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/exitlinks.sol";

error RawLinkInvalid();
error RawLinkInvalidBadKind();
error RawExitInvalid();

struct RawLink {
    bytes kindexits; // kind byte followed by a 2 pairs of exit bytes
}

struct RawExit {
    bytes linkloc;
}

library HexExits {
    using Exits for Exit;
    using Exits for Link;

    function load(Exit storage self, RawExit memory raw) internal {

        if (raw.linkloc.length != 4) {
            revert RawExitInvalid();
        }

        uint16 id = uint16(uint8(raw.linkloc[0])) << 8;
        id |= uint8(raw.linkloc[1]);
        self.link = LinkID.wrap(id);

        id = uint16(uint8(raw.linkloc[2])) << 8;
        id |= uint8(raw.linkloc[3]);
        self.loc = LocationID.wrap(id);
    }
    function load(Link storage self, RawLink memory raw) internal {

        if (raw.kindexits.length != 5) {
            revert RawLinkInvalid();
        }

        uint8 kind = uint8(raw.kindexits[0]);

        if (kind == 0 || kind >= uint8(Links.Kind.Invalid)) {
            revert RawLinkInvalidBadKind();
        }
        self.kind = Links.Kind(kind);

        uint16 id = uint16(uint8(raw.kindexits[1])) << 8;
        id |= uint8(raw.kindexits[2]);
        self.exits[0] = ExitID.wrap(id);

        id = uint16(uint8(raw.kindexits[3])) << 8;
        id |= uint8(raw.kindexits[4]);
        self.exits[1] = ExitID.wrap(id);

        // everything else can be the natural zero values
    }

    function load(Exit memory self, RawExit memory raw) internal pure {

        if (raw.linkloc.length != 4) {
            revert RawExitInvalid();
        }

        uint16 id = uint16(uint8(raw.linkloc[0])) << 8;
        id |= uint8(raw.linkloc[1]);
        self.link = LinkID.wrap(id);

        id = uint16(uint8(raw.linkloc[2])) << 8;
        id |= uint8(raw.linkloc[3]);
        self.loc = LocationID.wrap(id);
    }

    function load(Link memory self, RawLink memory raw) internal pure {

        if (raw.kindexits.length != 5) {
            revert RawLinkInvalid();
        }

        uint8 kind = uint8(raw.kindexits[0]);

        if (kind == 0 || kind >= uint8(Links.Kind.Invalid)) {
            revert RawLinkInvalidBadKind();
        }
        self.kind = Links.Kind(kind);

        uint16 id = uint16(uint8(raw.kindexits[1])) << 8;
        id |= uint8(raw.kindexits[2]);
        self.exits[0] = ExitID.wrap(id);

        id = uint16(uint8(raw.kindexits[3])) << 8;
        id |= uint8(raw.kindexits[4]);
        self.exits[1] = ExitID.wrap(id);

        // everything else can be the natural zero values
    }
}