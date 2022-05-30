// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;

import "forge-std/src/Test.sol";
import "forge-std/src/Vm.sol";
import "lib/mapstructure.sol";

contract Calldata {

    ExitID[] _sides;

    function reset() public  {
        delete _sides;
    }

    function RawLocation_kind(RawLocation calldata raw) public pure returns (Locations.Kind) {
        return Locations.kind(raw);
    }

    function RawLocation_setSides(bytes calldata rawSides) public returns (ExitID[] memory) {
        reset();
        Locations.setSides(_sides, rawSides);
        ExitID[] memory sides = new ExitID[](_sides.length);

        for (uint8 i =0; i < uint8(sides.length); i++) {
            sides[i] = _sides[i];
        }
        return sides;
    }

}

contract LocationTest is DSTest {
    using stdStorage for StdStorage;
    using Locations for Location;

    Vm private vm = Vm(HEVM_ADDRESS);
    Location[] private locs;
    uint16 nextExitID;

    Calldata private calld;

    StdStorage private stdstore;

    function setUp() public {
        nextExitID = 1;
        locs.push(); // id zero should be invalid always
        calld = new Calldata();
    }

    function defaultLocationNoExits() internal returns (Location storage) {
        locs.push();
        return locs[locs.length - 1];
    }

    // single exit each side
    function defaultLocation() internal returns (Location storage) {
        locs.push();
        Location storage loc = locs[locs.length - 1];
        loc.sides[uint16(Locations.SideKind.North) - 1].push(ExitID.wrap(nextExitID++));
        loc.sides[uint16(Locations.SideKind.West) - 1].push(ExitID.wrap(nextExitID++));
        loc.sides[uint16(Locations.SideKind.South) - 1].push(ExitID.wrap(nextExitID++));
        loc.sides[uint16(Locations.SideKind.East) - 1].push(ExitID.wrap(nextExitID++));
        return loc;
    }

    function testLocationSetSides() public {

        // just reminding myself of the endian and shifting rules here
        bytes memory b = bytes(hex"1001");
        assertEq(uint8(b[0]), uint8(16));
        assertEq(uint8(b[1]), uint8(1));
        uint16 u16 = uint16(uint8(b[0])) << 8;
        u16 |= uint8(b[1]);
        assertEq(u16, uint16(4097));
        bytes memory raw = bytes(hex"000100022001");
        assertEq(raw.length, 6);
        ExitID []memory sides = calld.RawLocation_setSides(raw);
        assertEq(ExitID.unwrap(sides[0]), uint16(1));
        assertEq(ExitID.unwrap(sides[1]), uint16(2));
        assertEq(ExitID.unwrap(sides[2]), uint16(8193));
    }

    function testLocationKindRoom() public {
        RawLocation memory x=RawLocation([bytes("\x01"), bytes(hex""), bytes(""), bytes(""), bytes("")]);
        assertTrue(calld.RawLocation_kind(x) == Locations.Kind.Room);
    }

    function testLocationKindIntersection() public {
        RawLocation memory x=RawLocation([bytes("\x02"), bytes(""), bytes(""), bytes(""), bytes("")]);
        assertTrue(calld.RawLocation_kind(x) == Locations.Kind.Intersection);
    }

    function testLocationKindCorridor() public {
        RawLocation memory x=RawLocation([bytes("\x03"), bytes(""), bytes(""), bytes(""), bytes("")]);
        assertTrue(calld.RawLocation_kind(x) == Locations.Kind.Corridor);
    }

    function testFailLocationKindInvalid() public view {
        RawLocation memory x=RawLocation([bytes("\x04"), bytes(""), bytes(""), bytes(""), bytes("")]);
        calld.RawLocation_kind(x);
    }
    function testFailLocationKindMoreInvalid() public view {
        RawLocation memory x=RawLocation([bytes("\x14"), bytes(""), bytes(""), bytes(""), bytes("")]);
        calld.RawLocation_kind(x);
    }

    function testFailExitIDUndefinedSide() public {
        Location storage loc = defaultLocationNoExits();
        loc.exitID(Locations.SideKind.Undefined, 0);
    }

    function testExitIndexLookup() public {

        uint16 firstExitID = nextExitID;
        Location storage loc = defaultLocation();

        for (uint8 i=0; i<4; i++) {
            ExitID.unwrap(loc.exitID(Locations.SideKind(i+1), 0)) == firstExitID++;
        }
    }

    function testFailExitIDNorthIndexOutOfRange1() public {
        // default location has no exits on any side
        Location storage loc = defaultLocationNoExits();
        loc.exitID(Locations.SideKind.North, 1);
    }
    function testFailExitIDWestIndexOutOfRange1() public {
        Location storage loc = defaultLocationNoExits();
        loc.exitID(Locations.SideKind.West, 1);
    }
    function testFailExitIDSouthIndexOutOfRange1() public {
        Location storage loc = defaultLocationNoExits();
        loc.exitID(Locations.SideKind.South, 1);
    }
    function testFailExitIDEastIndexOutOfRange1() public {
        Location storage loc = defaultLocationNoExits();
        loc.exitID(Locations.SideKind.East, 1);
    }

    // same again but lets have sides
    function testFailExitIDNorthIndexOutOfRange2() public {
        // default location has no exits on any side
        Location storage loc = defaultLocation();
        loc.exitID(Locations.SideKind.North, 2);
    }
    function testFailExitIDWestIndexOutOfRange2() public {
        Location storage loc = defaultLocation();
        loc.exitID(Locations.SideKind.West, 2);
    }
    function testFailExitIDSouthIndexOutOfRange2() public {
        Location storage loc = defaultLocation();
        loc.exitID(Locations.SideKind.South, 2);
    }
    function testFailExitIDEastIndexOutOfRange2() public {
        Location storage loc = defaultLocation();
        loc.exitID(Locations.SideKind.East, 2);
    }

}
