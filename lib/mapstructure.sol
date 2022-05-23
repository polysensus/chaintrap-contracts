// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;
import "./errors.sol";
import "./exitlinks.sol";
import "./locations.sol";


/// @title Defines a dungeon map in terms of locations, links and exits
struct Map {
    Location[] locations;
    Link[] links;
    Exit[] exits;
}

/// InvalidLocation raised if an invalid location id is provided
error InvalidLocation(uint16 id);

library LocationMaps {

    using Links for Link;
    using Locations for Location;
    using Locations for RawLocation;
    using Links for Exit;
    using Exits for Exit;

    /// ---------------------------
    /// @dev state changing methods

    // global initialisation & reset
    function _init(Map storage self) internal {

        if (self.locations.length != 0 || self.links.length != 0 || self.exits.length != 0 ) {
            revert IsInitialised();
        }
        // 0 is always invalid
        self.locations.push();
        self.links.push();
        self.exits.push();
    }

    function _reset(Map storage self) internal {
        delete self.locations;
        delete self.links;
        delete self.exits;

        _init(self);
    }
    /// ---------------------------
    /// map loading and validation - once its on the chain it is visible to all

    function load(Map storage self, RawLocation[] calldata raw) internal {
        for (uint16 i=0; i< raw.length; i++) {
            self.locations.push();
            self.locations[self.locations.length - 1].load(raw[i]);
        }
    }

    function load(Map storage self, RawExit[] calldata raw) internal {
        for (uint16 i=0; i< raw.length; i++) {
            self.exits.push();
            self.exits[self.exits.length - 1].load(raw[i]);
        }
    }

    function load(Map storage self, RawLink[] calldata raw) internal {
        for (uint16 i=0; i< raw.length; i++) {
            self.links.push();
            self.links[self.links.length - 1].load(raw[i]);
        }
    }



    // --- locations and links
    function traverse(
        Map storage self, ExitID egressVia) internal returns (ExitID) {

        Exit storage ex = exit(self, egressVia);
        Link storage ln = link(self, ex.link);

        return ln.traverse(egressVia);
    }


    /// ---------------------------
    /// @dev state reading methods

    // --- locations

    function trylocation(Map storage self, uint16 i) internal view returns (bool, Location storage) {
        if (i == 0 || i >= self.locations.length) {
            return (false, self.locations[0]);
        }
        return (true, self.locations[i]);
    }

    function trylocation(Map storage self, LocationID id) internal view returns (bool, Location storage) {
        return trylocation(self, LocationID.unwrap(id));
    }

    function location(
        Map storage self, uint16 i) internal view returns (Location storage) {

        if (i == 0 || i >= self.locations.length) {
            revert InvalidLocation(i);
        }
        return self.locations[i];
    }

    function location(
        Map storage self, LocationID id) internal view returns (Location storage) {
        return location(self, LocationID.unwrap(id));
    }

    // --- exits
    function exit(
        Map storage self, uint16 i) internal view returns (Exit storage) {

        if (i == 0 || i >= self.exits.length) {
            revert InvalidExit(i);
        }
        return self.exits[i];
    }

    function exit(
        Map storage self, ExitID id) internal view returns (Exit storage) {
        return exit(self, ExitID.unwrap(id));
    }

    /// @dev return the location id that this exit is part of
    function locationid(
        Map storage self, ExitID id) internal view returns (LocationID) {
        Exit storage e = exit(self, id);
        return e.loc;
    }


    // --- links and exits

    function link(
        Map storage self, uint16 i) internal view returns (Link storage) {
        if (i == 0 || i >= self.links.length) {
            revert InvalidLink();
        }
        return self.links[i];
    }

    function link(
        Map storage self, LinkID id) internal view returns (Link storage) {
        return link(self, LinkID.unwrap(id));
    }
}