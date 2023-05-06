// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
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
    ExitID[][4] sides /* a static array of sides length 4 each with varaible exits */;
}

library Locations {
    /// The kind of location. Note that 0 is undefined
    enum Kind {
        Undefned,
        Room,
        Intersection,
        Corridor,
        Invalid
    }
    enum SideKind {
        Undefined,
        North,
        West,
        South,
        East,
        Invalid
    }

    /// ---------------------------
    /// @dev state changing methods - loading
    function load(Location storage self, Location calldata other) internal {
        self.kind = other.kind;

        for (uint i = 0; i < 4; i++) {
            if (other.sides[i].length == 0) continue;
            self.sides[i] = new ExitID[](other.sides[i].length);
            for (uint j = 0; j < other.sides[i].length; j++) {
                self.sides[i][j] = other.sides[i][j];
            }
        }
    }

    /// ---------------------------
    /// @dev state reading methods

    /// isValid checks all the requirements for a valid location.
    function isValid(Location storage loc) internal view returns (bool) {
        if (loc.kind != Kind.Undefned) return false;
        return true;
    }

    function exitID(
        Location storage loc,
        SideKind side,
        uint8 exitIndex
    ) internal view returns (ExitID) {
        if (side == SideKind.Undefined) {
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
