// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;
import "./exitlinks.sol";

/// InvalidSide is raised if an invalid side kind is provided
error InvalidSide();

// @dev InvalidSideEnum means the enum definition for the sides has been changed
// and can no longer be used as an index.
error InvalidSideEnum();

/// InvalidExitIndex is raised if the location side does not have an exit corresponding to the supplied index
error InvalidExitIndex(uint8 i);

/// @title Defines a room, intersection, corridor,  or generic location
/// For Rooms, all four sides are walls.  For corridors, only two sides are
/// walls. For intersections all sides are completely filled by  doors or
/// archways. A room can have an number of doors in any side. An intersection
/// may have only 1 or 0 doorways. A corridor always has 2 (we don't currently
/// support deadend corridors)
/// @dev Only locations can be reached via Links & exits
struct Location {
    Locations.Kind kind;

    /// @dev corridors have no exits in any side.
    ExitID[][4] sides; /* a static array of sides length 4 each with varaible exits */
    /// @dev TODO just work with byte strings where each two byte element is a big endian uint16
}

error InvalidRawLocationKind();
error RawSidesMustBeEvenLength(uint length);
error ToManyExitsForSide();

struct RawLocation {
    /// @dev the first 'side' is a single byte identifying the kind. the subsequent 4 sides are byte arrays
    /// where each two successive items are the uint16 big-endian exit id's
    bytes [5]sides;
}

library Locations {

    /// The kind of location. Note that 0 is undefined
    enum Kind {Undefned, Room, Intersection, Corridor, Invalid}
    enum SideKind {Undefined, North, West, South, East, Invalid}

    /// ---------------------------
    /// @dev state changing methods - loading
    function kind(RawLocation calldata self) internal pure returns (Locations.Kind) {
        if (self.sides[0].length > 1 || self.sides[0].length == 0) {
            revert InvalidRawLocationKind();
        }
        if (self.sides[0][0] == 0 || uint8(self.sides[0][0]) >= uint8(Locations.Kind.Invalid)) {
            revert InvalidRawLocationKind();
        }
        return Locations.Kind(uint8(self.sides[0][0]));
    }

    function setSides(ExitID[] storage sides, bytes calldata rawSides) internal {
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

    function load(Location storage self, RawLocation calldata raw) internal {
        self.kind = kind(raw);

        for (uint i=0; i<4; i++) {
            setSides(self.sides[i], raw.sides[i+1]);
        }
    }

    /// ---------------------------
    /// @dev state reading methods

    /// isValid checks all the requirements for a valid location.
    function isValid(Location storage loc) internal view returns (bool) {
        if (loc.kind != Kind.Undefned) return false;
        return true;
    }

    function exitID(Location storage loc, SideKind side, uint8 exitIndex) internal view returns (ExitID) {

        if (side ==  SideKind.Undefined) {
            revert InvalidSide();
        }

        uint8 sideIndex = uint8(side) - 1;
        if (sideIndex >= 4) {
            revert InvalidSideEnum();
        }

        /* note: solidity arrays are not c arrays, the static dimension is indexed first*/
        if (exitIndex >= loc.sides[sideIndex].length) {
            revert InvalidExitIndex(exitIndex);
        }
        return loc.sides[sideIndex][exitIndex];
    }
}