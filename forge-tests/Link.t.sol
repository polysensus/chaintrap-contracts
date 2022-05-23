// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;

import "forge-std/src/Test.sol";
import "forge-std/src/Vm.sol";
import "../lib/exitlinks.sol";

contract LinkTest is DSTest {
    using stdStorage for StdStorage;
    using Links for Link;

    Vm private vm = Vm(HEVM_ADDRESS);
    Link[] private links;
    Exit[] private exits;

    StdStorage private stdstore;

    function setUp() public {
        // Deploy Map contract
        links.push(); // id zero should be invalid always
        exits.push();
    }

    function defaultLink() internal returns (Link storage) {
        uint16 id = uint16(links.length);
        links.push();
        return links[id];
    }

    function defaultLinkID() internal returns (LinkID) {
        uint16 i = uint16(links.length);
        links.push();
        Link storage ln = links[i];
        ln.kind = Links.Kind.Door;
        (ln.exits[0], ln.exits[1]) = (defaultExitID(), defaultExitID());
        return LinkID.wrap(i);
    }

    function defaultExitID() internal returns (ExitID) {
        uint16 i = uint16(exits.length);
        exits.push();
        return ExitID.wrap(i);
    }

    function link(LinkID id) internal view returns (Link storage) {
        return links[LinkID.unwrap(id)];
    }

    // -----------------------------------------------------------------------
    // traversal
    // -----------------------------------------------------------------------
    function testFailTraverseLocked() public {
        Link storage l1 = link(defaultLinkID());
        l1.lock();
        l1.traverse(l1.exits[0]);
    }

    function testTraverseOpen01() public {
        Link storage l1 = link(defaultLinkID());
        l1.open();
        uint16 ig = ExitID.unwrap(l1.traverse(l1.exits[0]));
        assertEq(ig, ExitID.unwrap(l1.exits[1]));
    }

    function testTraverseOpen10() public {
        Link storage l1 = link(defaultLinkID());
        l1.open();
        uint16 ig = ExitID.unwrap(l1.traverse(l1.exits[1]));
        assertEq(ig, ExitID.unwrap(l1.exits[0]));
    }

    function testTraverseClosed01RemainsOpenAfterUse() public {
        Link storage l1 = link(defaultLinkID());
        l1.close();
        uint16 ig = ExitID.unwrap(l1.traverse(l1.exits[0]));
        assertEq(ig, ExitID.unwrap(l1.exits[1]));
        assertTrue(l1._open);
    }

    function testTraverseOpen10RemainsOpenAfterUse() public {
        Link storage l1 = link(defaultLinkID());
        l1.close();
        uint16 ig = ExitID.unwrap(l1.traverse(l1.exits[1]));
        assertEq(ig, ExitID.unwrap(l1.exits[0]));
        assertTrue(l1._open);
    }


    // -----------------------------------------------------------------------
    // exits
    // -----------------------------------------------------------------------
    function testOtherLandingDefaultsInvalidByID() public {

        // the default initialisations should result in 'by id' requests being invalid
        Link storage l1 = defaultLink();

        assertEq(
            ExitID.unwrap(l1.tryotherExit(ExitID.wrap(0))), 
            ExitID.unwrap(invalidExitID));
    }

    function testOtherLandingDefaultsInvalidByIndex() public {

        // the default initialisations should result in 'by id' requests being invalid
        Link storage l1 = defaultLink();

        assertEq(
            ExitID.unwrap(l1.tryotherExit(uint8(0))), 
            ExitID.unwrap(invalidExitID));

        assertEq(
            ExitID.unwrap(l1.tryotherExit(uint8(1))), 
            ExitID.unwrap(invalidExitID));
    }

    function testOtherLandingInvalidByIDAlwaysGetsInvalidID() public {
        Link storage l1 = defaultLink();
        l1.exits[0] = ExitID.wrap(1);
        l1.exits[1] = ExitID.wrap(2);

        assertEq(
            ExitID.unwrap(l1.tryotherExit(ExitID.wrap(0))), 
            ExitID.unwrap(invalidExitID));
    }

    function testOtherLandingInvalidByID() public {
        Link storage l1 = defaultLink();
        l1.exits[0] = ExitID.wrap(1);
        l1.exits[1] = ExitID.wrap(2);

        assertEq(
            ExitID.unwrap(l1.tryotherExit(l1.exits[0])), 
            ExitID.unwrap(l1.exits[1]));

        assertEq(
            ExitID.unwrap(l1.tryotherExit(l1.exits[1])), 
            ExitID.unwrap(l1.exits[0]));

    }

    function testOtherLandingInvalidByIndex() public {
        Link storage l1 = defaultLink();
        l1.exits[0] = ExitID.wrap(1);
        l1.exits[1] = ExitID.wrap(2);

        assertEq(
            ExitID.unwrap(l1.tryotherExit(uint8(0))), 
            ExitID.unwrap(l1.exits[1]));

        assertEq(
            ExitID.unwrap(l1.tryotherExit(uint8(1))), 
            ExitID.unwrap(l1.exits[0]));
    }


    // -----------------------------------------------------------------------
    // open & locking
    // -----------------------------------------------------------------------

    // archways can not be closed. they are always open and, at all times the
    // state variables open & locked are ignored.
    function testLinkDefaultArchwayIsOpen() public {

        Link storage l1 = defaultLink();

        // Note that the defaults for open & locked are zero values which are both false.
        // but making the link an archway causes them to be ignored
        l1.kind = Links.Kind.Archway;
        assertTrue(l1.isOpen());
        assertTrue(l1.isEnterable());


        // even if its closed
        l1._open = false;
        assertTrue(l1.isOpen());
        assertTrue(l1.isEnterable());

        // even if it is locked
        l1._locked = true;
        assertTrue(l1.isOpen());
        assertTrue(l1.isEnterable());
        assertTrue(l1.open());
    }

    // A door defaults closed and not locked
    function testLinkDefaultDoorIsClosedAndNotLocked() public {

        Link storage l1 = defaultLink();

        // Note that the defaults for open & locked are zero values which are both false.
        // but making the link an archway causes them to be ignored
        l1.kind = Links.Kind.Door;
        assertTrue(!l1.isOpen());
        assertTrue(!l1.isEnterable());
        assertTrue(!l1.isLocked());
    }

    // A default door can be imediately opend (as its not locked)
    function testLinkDefaultDoorCanBeOpened() public {

        Link storage l1 = defaultLink();

        // Note that the defaults for open & locked are zero values which are both false.
        // but making the link an archway causes them to be ignored
        l1.kind = Links.Kind.Door;
        assertTrue(!l1.isOpen());
        assertTrue(!l1.isEnterable());
        assertTrue(!l1.isLocked());

        assertTrue(l1.open());
        assertTrue(l1.isEnterable());
    }

    function testLinkDefaultDoorCanBeOpenedAndThenLocked() public {
        Link storage l1 = defaultLink();

        l1.kind = Links.Kind.Door;

        assertTrue(l1.open());
        assertTrue(l1.isEnterable());

        // Now lock it
        assertTrue(l1.lock());

        // Because it is standing open it should be enterable
        assertTrue(l1.isEnterable());

        // And yet it is locked
        assertTrue(l1.isLocked());
    }

    // A door can be locked while open. It is then effectively a trap.
    // if it closes it can't be re-opened without unlocking
    function testLinkOpenLockedDoorCantBeOpenedAfterClosing() public {
        Link storage l1 = defaultLink();

        l1.kind = Links.Kind.Door;

        assertTrue(l1.open());
        assertTrue(l1.isEnterable());

        // Now lock it
        assertTrue(l1.lock());

        // Because it is standing open it should be enterable
        assertTrue(l1.isEnterable());

        // And yet it is locked
        assertTrue(l1.isLocked());

        assertTrue(l1.close());
        // Now it can't be opened
        assertTrue(!l1.open());
    }

    // By default a lockable door does not have a key holder. this makes it a
    // trap and the door can never be unlocked.
    function testDefaultLockedDoorUnlockByKeyHolder() public {

        Link storage l1 = defaultLink();

        l1.kind = Links.Kind.Door;

        assertTrue(l1.close());
        assertTrue(l1.lock());

        assertTrue(!l1.isEnterable());
        assertTrue(l1.isLocked());

        // Now it can't be opened
        assertTrue(!l1.open());

        // As we don't have a keyHolder, it cant be unlocked
        assertTrue(!l1.unlock(KeyID.wrap(0)));

        // set the keyHolder and we can then open it *with a valid key*
        l1.key = KeyID.wrap(1);
        assertTrue(l1.unlock(KeyID.wrap(1)));
        assertTrue(l1.open());
    }
}

