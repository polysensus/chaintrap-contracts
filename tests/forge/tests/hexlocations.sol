// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/locations.sol";

error InvalidRawLocationKind();
error RawSidesMustBeEvenLength(uint length);
error ToManyExitsForSide();
error SideExitArrayMisAllocated(uint length, uint count);

struct RawLocation {
    /// @dev the first 'side' is a single byte identifying the kind. the subsequent 4 sides are byte arrays
    /// where each two successive items are the uint16 big-endian exit id's
    bytes [5]sides;
}

library HexLocations {

    using HexLocations for Location;

    /*
    function load(Location storage self, RawLocation calldata raw) internal {
        self.kind = kind(raw);

        for (uint i=0; i<4; i++) {
            setSides(self.sides[i], raw.sides[i+1]);
        }
    }*/

    function load(Location storage self, RawLocation memory raw) internal {
        self.kind = kind(raw);

        for (uint i=0; i<4; i++) {
            uint n = raw.sides[i+1].length >> 1;
            if (n == 0) continue;
            setSides(self.sides[i], raw.sides[i+1]);
        }
    }

    function load(Location memory self, RawLocation memory raw) internal pure {
        self.kind = kind(raw);
        for (uint i=0; i<4; i++) {

            uint n = raw.sides[i+1].length >> 1;
            if (n == 0) continue;

            self.sides[i] = new ExitID[](n);
            loadSides(self.sides[i], raw.sides[i+1]);
        }
    }

    function kind(RawLocation memory self) internal pure returns (Locations.Kind) {
        if (self.sides[0].length > 1 || self.sides[0].length == 0) {
            revert InvalidRawLocationKind();
        }
        if (self.sides[0][0] == 0 || uint8(self.sides[0][0]) >= uint8(Locations.Kind.Invalid)) {
            revert InvalidRawLocationKind();
        }
        return Locations.Kind(uint8(self.sides[0][0]));
    }

    function loadSides(ExitID[] memory sides, bytes memory rawSides)  internal pure {
        uint len = rawSides.length;
        uint count = rawSides.length >> 1;
        if (len % 2 != 0) {
            revert RawSidesMustBeEvenLength(len);
        }
        if (len >= 256 * 2) {
            revert ToManyExitsForSide();
        }
        if (sides.length != count)
            revert SideExitArrayMisAllocated(sides.length, count);

        for (uint i=0; i<count; i++ ) {
            uint16 id = uint16(uint8(rawSides[i*2+0])) << 8;
            id |= uint8(rawSides[i*2+1]);
            sides[i] = ExitID.wrap(id);
        }
    }

    function setSides(ExitID[] storage sides, bytes memory rawSides) internal {
        if (rawSides.length % 2 != 0) {
            revert RawSidesMustBeEvenLength(rawSides.length);
        }
        if (rawSides.length >= 256 * 2) {
            revert ToManyExitsForSide();
        }

        for (uint i=0; i<rawSides.length; i+=2 ) {

            uint16 id = uint16(uint8(rawSides[i+0])) << 8;
            id |= uint8(rawSides[i+1]);
            sides.push(ExitID.wrap(id));
        }
    }
}