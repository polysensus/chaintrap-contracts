// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "lib/locations.sol";
import "lib/transcript.sol";
import "lib/game.sol";

contract Factory {

    /// @dev this exists to enable testing of methods which require calldata

    using Transcripts for Transcript;
    using Games for Game;

    Transcript[] trans;
    Game[] games;

    constructor () {
        trans.push();
        trans[0]._init(GameID.wrap(0));
        games.push();
        games[0]._init(2);
    }

    function reset() public {
        delete trans;
        trans.push();
        trans[trans.length - 1]._init(GameID.wrap(0));
    }

    function head() internal view returns (Transcript storage) {
        return trans[trans.length-1];
    }

    function headGame() internal view returns (Game storage) {
        return games[games.length-1];
    }

    function push() public {
        trans.push();
        trans[trans.length - 1]._init(GameID.wrap(games.length));
        games.push();
        games[games.length - 1]._init(2);
    }

    // utility methods based on the proxy methods
    function transcriptLength() public view returns (uint) {
        uint n = 0;
        TEID cur = cursorStart;

        for(bool completed = false;!completed; (cur, , completed) = head().next(cur)) {
            n += 1;
        }
        return n;
    }

    // checking methods
    function linkEq(LinkID id, Link memory expect) public view returns (bool) {

        Link storage ln = headGame().link(id);
        if (expect.kind !=  ln.kind) {
            return false;
        }
 
        if (ExitID.unwrap(expect.exits[0]) != ExitID.unwrap(ln.exits[0])) {
            return false;
        }

        if (ExitID.unwrap(expect.exits[1]) != ExitID.unwrap(ln.exits[1])) {
            return false;
        }

        if (KeyID.unwrap(expect.key) != KeyID.unwrap(ln.key)) {
            return false;
        }

        return true;
    }

    function exitEq(ExitID id, Exit memory expect) public view returns (bool) {

        Exit storage exit = headGame().exit(id);
        if (LinkID.unwrap(expect.link) != LinkID.unwrap(exit.link)) {
            return false;
        }
        if (LocationID.unwrap(expect.loc) != LocationID.unwrap(exit.loc)) {
            return false;
        }
        return true;
    }

    function locationEq(LocationID id, Location memory expect) public view returns (bool) {

        // f.locationEq(LocationID.wrap(1), loc);
        Location storage loc = headGame().location(id);
        if (expect.kind !=  loc.kind) {
            return false;
        }
        for (uint8 i=uint8(Locations.SideKind.North); i < uint8(Locations.SideKind.Invalid); i++) {
            if (expect.sides[i-1].length != loc.sides[i-1].length) {
                return false;
            }
            for (uint8 j=0; j<loc.sides[i-1].length; j++) {
                if (ExitID.unwrap(expect.sides[i-1][j]) != ExitID.unwrap(loc.sides[i-1][j])) {
                    return false;
                }
            }
        }
        return true;
    }

    function locationKindEq(LocationID id, Location memory expect) public view returns (bool) {

        // f.locationEq(LocationID.wrap(1), loc);
        Location storage loc = headGame().location(id);
        if (expect.kind !=  loc.kind) {
            return false;
        }
        return true;
    }

    function locationSideEq(LocationID id, Location memory expect, Locations.SideKind side) public view returns (bool) {

        // f.locationEq(LocationID.wrap(1), loc);
        Location storage loc = headGame().location(id);
        uint8 i = uint8(side);

        if (expect.sides[i-1].length != loc.sides[i-1].length) {
            return false;
        }

        for (uint8 j=0; j<loc.sides[i-1].length; j++) {
            if (ExitID.unwrap(expect.sides[i-1][j]) != ExitID.unwrap(loc.sides[i-1][j])) {
                return false;
            }
        }
        return true;
    }

    // proxy methods
    function load(RawLocation[] calldata raw) public {
        headGame().load(raw);
    }
    function load(RawExit[] calldata raw) public {
        headGame().load(raw);
    }

    // loadLink because link with this type is an overload clash
    function loadLinks(RawLink[] calldata raw) public {
        headGame().load(raw);
    }

    function load(TranscriptLocation[]calldata locations) public {
        headGame().load(locations);
    }

    function start() public {
        headGame().start();
    }

    function complete() public {
        headGame().complete();
    }

    function registerPlayer(address p, bytes32 startLocation, bytes calldata sceneblob, bytes calldata profile) public {
        headGame().joinGame(p, profile);
        headGame().setStartLocation(p, startLocation, sceneblob);
    }

    function playerRegistered(address p) public view returns (bool) {
        return headGame().playerRegistered(p);
    }

    function playerLocation(address p) public view returns (LocationID) {
        return headGame().player(p).loc;
    }

    // playback and enumeration
    function playCurrentTranscript() public  returns (TEID){
        return headGame().playTranscript(trans[trans.length-1]);
    }

    function playCurrentTranscript(TEID cur, TEID end) public returns (TEID) {
        return headGame().playTranscript(trans[trans.length-1], cur, end);
    }

    function enumerateCurrentTranscript() public view {

        TEID cur = cursorStart;
        uint16 end = 0;
        bool completed = false;
        TranscriptEntry memory te;
        Game storage game = headGame();
        Transcript storage t = trans[trans.length -1];

        for(;!completed && (end == 0 || TEID.unwrap(cur) != end);) {

            (cur, te, completed) = t.next(cur);

            Player storage p = game.player(te.player);
            if (p.halted) {
                revert Halted(te.player);
            }
        }
    }

    function next(TEID cur) public view returns (TEID, TranscriptEntry memory, bool) {
        return head().next(cur);
    }

    // committing and allowing
    function reject(TEID id) public {
        head().reject(id);
    }

    function rejectAndHalt(TEID id) public {
        head().rejectAndHalt(id);
    }

    function allowAndHalt(TEID id) public {
        head().allowAndHalt(id);
    }

    function commitExitUse(address player, ExitUse calldata committed) public returns (TEID) {
        return head().commitExitUse(player, committed);
    }

    function allowExitUse(TEID id, ExitUseOutcome calldata outcome) public {
        head().allowExitUse(id, outcome);
    }
}

contract TranscriptTest is DSTest {
    using stdStorage for StdStorage;
    using Locations for Location;

    Vm private vm = Vm(HEVM_ADDRESS);
    Location[] private locs;
    uint16 nextExitID;
    uint256 blockNumberForLocationTokens;

    Factory private f;

    StdStorage private stdstore;

    function setUp() public {
        nextExitID = 1;
        locs.push(); // id zero should be invalid always
        f = new Factory();
        blockNumberForLocationTokens = 1;
    }

    /// XXX: TODO move these to Arena.t.sol

    /* The following layout is the default map for theses tests

        (not doing corridors at all in this, its all just rooms)

        +------+---------------------------+-----+
        | 1 (1)|-(2)  2                (3)-|-(4) |  
        +-+----+                           |   3 |
          |(9)-|-(5)                       +-----+
          | 4  |(6)              (7)   (8) |
          +----+-|-------+--------|-----|--+
          | 5  (10) (11)-|-(12) 6(13) (14) |
          +--------------+-----------------+

          A full transcript would be

          (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
          (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
          (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
          (6,10)  exitUse(South, 0) ln4 -> (North,0) loc5
          (11,12) exitUse(East, 0)  ln7 -> (West, 0) loc6
          (7,13)  exitUse(North, 0) ln5 -> (South,2) loc2
          (8,14)  exitUse(South, 2) ln6 -> (North,1) loc6
          (8,14)  exitUse(North, 1) ln2 -> (South,2) loc2
          (3,4)   exitUse(East, 0)  ln2 -> (West, 0) loc3
     */
    function loadDefaultMap() public {

        // kind, North, West, South, East
        //
        // doors on each side are 'reading order' west -> east, north -> south

        RawLocation[] memory locations = new RawLocation[](6);

        locations[0].sides = [bytes(hex"01"), hex"",         hex"",         hex"",             hex"0001"];
        locations[1].sides = [bytes(hex"01"), hex"",         hex"00020005", hex"000600070008", hex"0003"];
        locations[2].sides = [bytes(hex"01"), hex"",         hex"0004",     hex"",             hex""];
        locations[3].sides = [bytes(hex"01"), hex"",         hex"",         hex"",             hex"0009"];
        locations[4].sides = [bytes(hex"01"), hex"000a",     hex"",         hex"",             hex"000b"];
        locations[5].sides = [bytes(hex"01"), hex"000d000e", hex"000c",     hex"",             hex""];
            
        f.load(locations);

        RawExit[] memory exits = new RawExit[](14);
        // room 1
        exits[0] = RawExit(hex"00010001"); // e1
        // room 2
        exits[1] = RawExit(hex"00010002"); // e2
        exits[2] = RawExit(hex"00020002"); // e3
        // room 3
        exits[3] = RawExit(hex"00020003"); // e4
        // room 2
        exits[4] = RawExit(hex"00030002"); // e5
        exits[5] = RawExit(hex"00040002"); // e6
        exits[6] = RawExit(hex"00050002"); // e7
        exits[7] = RawExit(hex"00060002"); // e8
        // room 4
        exits[8] = RawExit(hex"00030004"); // e9
        // room 5
        exits[9] = RawExit(hex"00040005"); // e10
        exits[10] = RawExit(hex"00070005"); // e11
        // room 6
        exits[11] = RawExit(hex"00070006"); // e12
        exits[12] = RawExit(hex"00050006"); // e13
        exits[13] = RawExit(hex"00060006"); // e14

        f.load(exits);

        RawLink[] memory links = new RawLink[](7);
        links[0] = RawLink(hex"0100010002"); // (1)-(2) ln1
        links[1] = RawLink(hex"0100030004"); // (3)-(4) ln2
        links[2] = RawLink(hex"0100050009"); // (5)-(9) ln3
        links[3] = RawLink(hex"010006000a"); // (6)-(10) ln4
        links[4] = RawLink(hex"010007000d"); // (7)-(13) ln5
        links[5] = RawLink(hex"010008000e"); // (8)-(14) ln6
        links[6] = RawLink(hex"01000b000c"); // (11)-(12) ln7

        f.loadLinks(links);
    }

    // allow for tokens which represent two players at the same place and time
    function _locationToken(uint16 id) internal returns (bytes32) {
        // TODO hashy things but the transcript checker doesn't support it yet
        bytes memory b = abi.encodePacked(blockNumberForLocationTokens, id);
        blockNumberForLocationTokens += 1;
        return keccak256(b);
    }

    function locationToken(uint16 id) internal returns (bytes32) {
        // TODO hashy things but the transcript checker doesn't support it yet
        bytes32 token = _locationToken(id);
        blockNumberForLocationTokens += 1;
        return token;
    }
   
    function locationToken(LocationID id) internal returns (bytes32) {
        return locationToken(uint16(LocationID.unwrap(id)));
    }

    function locationTE(LocationID id) internal returns (TranscriptLocation memory) {
        TranscriptLocation memory loc;
        loc.id = id;
        loc.blocknumber = blockNumberForLocationTokens;
        loc.token = locationToken(id);
        return loc;
    }

    function exitUse(Locations.SideKind kind, uint8 egressIndex) internal pure returns (ExitUse memory) {
        return ExitUse(kind, egressIndex);
    }

    function exitUseOutcome(Locations.SideKind kind, uint8 ingressIndex) internal pure returns (ExitUseOutcome memory) {
        return ExitUseOutcome(bytes32(0), bytes(""), kind, ingressIndex, false);
    }
    function exitUseOutcomeHalt(Locations.SideKind kind, uint8 ingressIndex) internal pure returns (ExitUseOutcome memory) {
        return ExitUseOutcome(bytes32(0), bytes(""), kind, ingressIndex, true);
    }

    function exitUseOutcome(bytes32 location, Locations.SideKind kind, uint8 ingressIndex) internal pure returns (ExitUseOutcome memory) {
        return ExitUseOutcome(location, bytes(""), kind, ingressIndex, false);
    }

    function testLoadSingleLocation() public {
        RawLocation[] memory locations = new RawLocation[](1);
        locations[0].sides = [bytes(hex"01"), hex"", hex"", hex"", hex"0001"];

        f.start();
        f.complete();
        f.load(locations);

        Location memory loc;
        loc.kind = Locations.Kind.Room;
        loc.sides[uint8(Locations.SideKind.East)-1] = new ExitID[](1);
        loc.sides[uint8(Locations.SideKind.East)-1][0] = ExitID.wrap(1);

        assertTrue(f.locationKindEq(LocationID.wrap(1), loc));
        assertTrue(f.locationSideEq(LocationID.wrap(1), loc, Locations.SideKind.East));
        assertTrue(f.locationEq(LocationID.wrap(1), loc));
    }

    function testLoadSingleExit() public {

        RawExit[] memory exits = new RawExit[](1);
        exits[0] = RawExit(hex"00010002"); // e1

        f.start();
        f.complete();
        f.load(exits);

        Exit memory exit;
        exit.link = LinkID.wrap(1);
        exit.loc = LocationID.wrap(2);
        assertTrue(f.exitEq(ExitID.wrap(1), exit));
    }

    function testLoadSingleLink() public {

        RawLink[] memory links = new RawLink[](1);
        links[0] = RawLink(hex"0100050009"); // (5)-(9) ln1

        Link memory ln;
        ln.kind = Links.Kind.Door;
        ln.exits[0] = ExitID.wrap(5);
        ln.exits[1] = ExitID.wrap(9);

        f.start();
        f.complete();
        f.loadLinks(links);

        assertTrue(f.linkEq(LinkID.wrap(1), ln));
    }

    function testDefaultTestMap() public {
        f.start();
        f.complete();
        loadDefaultMap();
    }

    function testPlayerRegistrationStartLocationValid() public {
        f.push();

        // Only the games master can know the start tokens for the players
        LocationID loc = LocationID.wrap(1);
        bytes32 token = locationToken(loc);


        f.registerPlayer(address(1), token, bytes(""), bytes(""));
        f.start();
        f.complete();

        loadDefaultMap();

        TranscriptLocation []memory locations = new TranscriptLocation[](1);
        locations[0].token = token;
        locations[0].id = loc; 
        f.load(locations);

        assertEq(LocationID.unwrap(loc), LocationID.unwrap(f.playerLocation(address(1))));
    }

    function testPlaybackSimplestViableGame() public {

        // this transitions from room 1 to room 2 and then plays back the transcript.
        // its the simplest viable game

        // push a clean game state and transcript
        f.push();

        // Only the games master can know the start tokens for the players
        LocationID startLocation = LocationID.wrap(1);
        bytes32 startToken = locationToken(startLocation);

        f.registerPlayer(address(1), startToken, bytes(""), bytes(""));

        f.start();

        TEID id = f.commitExitUse(address(1), exitUse(Locations.SideKind.East, 0));

        LocationID loc = LocationID.wrap(2);
        bytes32 token = locationToken(loc);

        f.allowExitUse(id, exitUseOutcome(token, Locations.SideKind.West, 0));
        f.complete();

        loadDefaultMap();

        TranscriptLocation []memory locations = new TranscriptLocation[](2);
        locations[0].token = startToken;
        locations[0].id = startLocation; 
        locations[1].token = token;
        locations[1].id = loc; 

        f.load(locations);

        f.playCurrentTranscript();
    }

    function commitAndAllowExitUse(
        Locations.SideKind egress, uint8 egressExit, Locations.SideKind ingress, uint8 ingressExit,
        bytes32 tokenizedLocation) internal returns (TEID) {

        TEID id = f.commitExitUse(address(1), exitUse(egress, egressExit));
        f.allowExitUse(id, exitUseOutcome(tokenizedLocation, ingress, ingressExit));
        return id;
    }

    function testPlaybackUseAllLinks() public {

        /*
        +------+---------------------------+-----+
        | 1 (1)|-(2)  2                (3)-|-(4) |  
        +-+----+                           |   3 |
          |(9)-|-(5)                       +-----+
          | 4  |(6)              (7)   (8) |
          +----+-|-------+--------|-----|--+
          | 5  (10) (11)-|-(12) 6(13) (14) |
          +--------------+-----------------+

        (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
        (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
        (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
        (6,10)  exitUse(South, 0) ln4 -> (North,0) loc5
        (11,12) exitUse(East, 0)  ln7 -> (West, 0) loc6
        (7,13)  exitUse(North, 0) ln5 -> (South,2) loc2
        (8,14)  exitUse(South, 2) ln6 -> (North,1) loc6
        (8,14)  exitUse(North, 1) ln2 -> (South,2) loc2
        (3,4)   exitUse(East, 0)  ln2 -> (West, 0) loc3
        */

        LocationID loc1 = LocationID.wrap(1);
        LocationID loc2 = LocationID.wrap(2);
        LocationID loc3 = LocationID.wrap(3);
        LocationID loc4 = LocationID.wrap(4);
        LocationID loc5 = LocationID.wrap(5);
        LocationID loc6 = LocationID.wrap(6);

        Locations.SideKind North = Locations.SideKind.North;
        Locations.SideKind West = Locations.SideKind.West;
        Locations.SideKind South = Locations.SideKind.South;
        Locations.SideKind East = Locations.SideKind.East;

        // note: ordinarily of course we can't know the location until the
        // player commits to it. for these tests we are both ends of the game.

        uint i=0;
        TranscriptLocation []memory locations = new TranscriptLocation[](10);
        TEID[] memory ids =  new TEID[](9);

        // start position
        locations[i++] = locationTE(loc1);

        f.registerPlayer(address(1), locations[0].token, bytes(""), bytes(""));

        f.start();

        // (1)(2)  exitUse(East, 0)  ln1 -> (West, 0) loc2  
        locations[i] = locationTE(loc2);
        ids[i-1] = commitAndAllowExitUse(East, 0, West, 0, locations[i].token); i++;

        // (5)(9)  exitUse(West, 1)  ln3 -> (East, 0) loc4
        locations[i] = locationTE(loc4);
        ids[i-1] = commitAndAllowExitUse(West, 1, East, 0, locations[i].token); i++;

        // (5)(9)  exitUse(East, 0)  ln3 -> (West, 1) loc2
        locations[i] = locationTE(loc2);
        ids[i-1] = commitAndAllowExitUse(East, 0, West, 1, locations[i].token); i++;

        // (6,10)  exitUse(South, 0) ln4 -> (North,0) loc5
        locations[i] = locationTE(loc5);
        ids[i-1] = commitAndAllowExitUse(South, 0, North, 1, locations[i].token); i++;

        // (11,12) exitUse(East, 0)  ln7 -> (West, 0) loc6
        locations[i] = locationTE(loc6);
        ids[i-1] = commitAndAllowExitUse(East, 0, West, 0, locations[i].token); i++;

        // (7,13)  exitUse(North, 0) ln5 -> (South,2) loc2
        locations[i] = locationTE(loc2);
        ids[i-1] = commitAndAllowExitUse(North, 0, South, 2, locations[i].token); i++;

        // (8,14)  exitUse(South, 2) ln6 -> (North,1) loc6
        locations[i] = locationTE(loc6);
        ids[i-1] = commitAndAllowExitUse(South, 2, North, 1, locations[i].token); i++;

        // (8,14)  exitUse(North, 1) ln2 -> (South,2) loc2
        locations[i] = locationTE(loc2);
        ids[i-1] = commitAndAllowExitUse(North, 1, South, 2, locations[i].token); i++;

        // (3,4)   exitUse(East, 0)  ln2 -> (West, 0) loc3
        locations[i] = locationTE(loc3);
        ids[i-1] = commitAndAllowExitUse(East, 0, West, 0, locations[i].token); i++;

        f.complete();

        loadDefaultMap();
        f.load(locations);

        TEID cur = cursorStart;

        // To aid debugging we use an explicit end.
        uint16 _end = 0;

        // play the first step of the transcript
        cur = f.playCurrentTranscript(cur, TEID.wrap(_end));
        assertTrue(TEID.unwrap(cur) ==  _end || _end ==0);

        // cur = f.playCurrentTranscript(cur, TEID.wrap(_end));
        // _end += 1;
        // assertEq(TEID.unwrap(cur), _end);
    }

    // @dev test the transcript is rejected if a move does not agree with the
    // map. regardless of whether the move was allowed by the games master.
    function testPlaybackIleagalExitUse() public {
        // this transitions from room 1 to room 2 and then plays back the transcript.
        // its the simplest viable game

        // Only the games master can know the start tokens for the players
        LocationID startLocation = LocationID.wrap(1);
        bytes32 startToken = locationToken(startLocation);

        f.registerPlayer(address(1), startToken, bytes(""), bytes(""));

        f.start();

        TEID id = f.commitExitUse(address(1), exitUse(Locations.SideKind.East, 3));

        LocationID loc = LocationID.wrap(2);
        bytes32 token = locationToken(loc);

        f.allowExitUse(id, exitUseOutcome(token, Locations.SideKind.West, 3));

        f.complete();

        loadDefaultMap();

        TranscriptLocation []memory locations = new TranscriptLocation[](2);
        locations[0].token = startToken;
        locations[0].id = startLocation; 
        locations[1].token = token;
        locations[1].id = loc; 

        f.load(locations);


        vm.expectRevert(abi.encodeWithSelector(InvalidExitIndex.selector, 3));
        f.playCurrentTranscript();
    }

    // testEnumeration* tests walk the transcript following the same playback
    // loop as the game but without executing the steps.
    function testEnumerateSimplestViableGame() public {

        // push a clean game state and transcript
        f.push();

        // Only the games master can know the start tokens for the players
        LocationID startLocation = LocationID.wrap(1);
        bytes32 startToken = locationToken(startLocation);
        f.registerPlayer(address(1), startToken, bytes(""), bytes(""));
        f.start();

        TEID id = f.commitExitUse(address(1), exitUse(Locations.SideKind.East, 0));

        LocationID loc = LocationID.wrap(2);
        bytes32 token = locationToken(loc);

        f.allowExitUse(id, exitUseOutcome(token, Locations.SideKind.West, 0));

        f.complete();

        loadDefaultMap();

        TranscriptLocation []memory locations = new TranscriptLocation[](2);
        locations[0].token = startToken;
        locations[0].id = startLocation; 
        locations[1].token = token;
        locations[1].id = loc; 

        f.load(locations);
        f.enumerateCurrentTranscript();
    }

    function testRegisterPlayer() public {

        LocationID startLocation = LocationID.wrap(1);
        bytes32 startToken = locationToken(startLocation);

        f.registerPlayer(address(1), startToken, bytes(""), bytes(""));

        assertTrue(f.playerRegistered(address(1)));
    }


    // -------------------------------------
    // halted player accumulation
    function testTranscriptCollectHalted() public {

        f.start();

        TEID id = f.commitExitUse(address(1), exitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 1));

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 1));

        id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 4));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 1));

        id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 4));
        f.allowExitUse(id, exitUseOutcomeHalt(Locations.SideKind.South, 1));

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 5));
        f.rejectAndHalt(id);

        TEID halted1;
        TEID halted2;
        TEID cur = cursorStart;
        bool complete = false;
        TranscriptEntry memory te;
        for(;!complete; (cur, te, complete) = f.next(cur)) {
            if(te.halted) {
                if (te.player == address(1)) halted1 = cur;
                if (te.player == address(2)) halted2 = cur;
            }
        }

        assertEq(TEID.unwrap(halted1), uint16(4));

        // *notice* this is 2 because the halt was a reject. so the last
        // succesful move counts as when the player halted.
        assertEq(TEID.unwrap(halted2), uint16(2));
    }

    function testTranscriptSingleEntryTEID() public {
        TEID id;

        f.start();

        id = f.commitExitUse(address(1), exitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 1));

        (TEID cur, ,) = f.next(cursorStart);
        assertEq(TEID.unwrap(cur), TEID.unwrap(id));
    }

    // testFailMoveWithoutAllow tests that attempting to move twice in a row
    // without getting the first move's outcome is disallowed
    function testFailMoveWithoutAllow() public {
        TEID id;

        f.start();

        id = f.commitExitUse(address(1), exitUse(Locations.SideKind.North, 1));
        id = f.commitExitUse(address(1), exitUse(Locations.SideKind.North, 1));
    }

    function testTranscriptTEIDs() public {

        TEID[5] memory ids;

        f.start();

        ids[0] = f.commitExitUse(address(1), exitUse(Locations.SideKind.North, 1));
        f.allowExitUse(ids[0], exitUseOutcome(Locations.SideKind.South, 1));

        ids[1] = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(ids[1], exitUseOutcome(Locations.SideKind.South, 1));

        ids[2] = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 4));
        f.allowExitUse(ids[2], exitUseOutcome(Locations.SideKind.South, 1));

        ids[3] = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 4));
        f.allowExitUse(ids[3], exitUseOutcomeHalt(Locations.SideKind.South, 1));

        ids[4] = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 5));
        f.rejectAndHalt(ids[4]);

        TEID cur = cursorStart;
        bool complete = false;
        TranscriptEntry memory te;
        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), TEID.unwrap(ids[0]));
        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), TEID.unwrap(ids[1]));
        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), TEID.unwrap(ids[2]));
        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), TEID.unwrap(ids[3]));
        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(0));

        cur=cursorStart;
        complete=false;
        for(uint i=0; !complete; i++) {
            (cur, te, complete) = f.next(cur);
            if (i!=4) {
                assertEq(TEID.unwrap(cur), TEID.unwrap(ids[i]));
                continue;
            }
            assertEq(TEID.unwrap(cur), uint16(0));
        }
    }
    // -------------------------------------
    // enumeration edge cases

    function testFailTranscriptEnumerateEmpty() public view {
        TEID cur = cursorStart;
        f.next(cur);
    }

    function testFailTranscriptEnumerateCursorOutOfRange() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 2));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 3));
        id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 3));

        f.next(TEID.wrap(3));
    }

    function testTranscriptEnumerateSingle() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        TEID cur = cursorStart;
        (TEID id1, TranscriptEntry memory te, bool complete) = f.next(cur);
        assertEq(TEID.unwrap(id1), uint16(1));
        assertEq(te.player, address(1));
        assertTrue(te.kind == Transcripts.MoveKind.ExitUse);
        assertTrue(!te.halted);
        assertTrue(complete);
    }

    function testTranscriptEnumerateTwo() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 4));

        TEID cur = cursorStart;
        TranscriptEntry memory te;
        bool complete;

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(1));
        assertTrue(!complete);
        assertEq(te.player, address(1));

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(2));
        assertEq(te.player, address(2));
        assertTrue(te.kind == Transcripts.MoveKind.ExitUse);
        assertTrue(!te.halted);
        assertTrue(complete);
    }

    function testTranscriptEnumerateTwoWithOneRejected() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.reject(id);

        id = f.commitExitUse(address(3), ExitUse(Locations.SideKind.North, 5));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 6));

        TEID cur = cursorStart;
        TranscriptEntry memory te;
        bool complete;

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(1));
        assertTrue(!complete);
        assertEq(te.player, address(1));

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(3));
        assertEq(te.player, address(3));
        assertTrue(te.kind == Transcripts.MoveKind.ExitUse);
        assertTrue(!te.halted);
        assertTrue(complete);
    }

    function testTranscriptEnumerateTwoWithFirstRejected() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.reject(id);

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        id = f.commitExitUse(address(3), ExitUse(Locations.SideKind.North, 5));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 6));

        TEID cur = cursorStart;
        TranscriptEntry memory te;
        bool complete;

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(2));
        assertTrue(!complete);
        assertEq(te.player, address(2));

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(3));
        assertEq(te.player, address(3));
        assertTrue(te.kind == Transcripts.MoveKind.ExitUse);
        assertTrue(!te.halted);
        assertTrue(complete);
    }

    function testTranscriptEnumerateTwoWithLastRejected() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));

        id = f.commitExitUse(address(2), ExitUse(Locations.SideKind.North, 3));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 4));

        id = f.commitExitUse(address(3), ExitUse(Locations.SideKind.North, 5));
        f.reject(id);

        TEID cur = cursorStart;
        TranscriptEntry memory te;
        bool complete;

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(1));
        assertTrue(!complete);
        assertEq(te.player, address(1));

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(2));
        assertEq(te.player, address(2));
        assertTrue(te.kind == Transcripts.MoveKind.ExitUse);
        assertTrue(!te.halted);
        assertTrue(!complete);

        (cur, te, complete) = f.next(cur);
        assertEq(TEID.unwrap(cur), uint16(0));
        assertEq(te.player, address(0));
        assertTrue(te.kind == Transcripts.MoveKind.Undefined);
        assertTrue(!te.halted);
        assertTrue(complete);

    }
    function testTranscriptCommitRecordsPlayer() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));
        (, TranscriptEntry memory te,) = f.next(cursorStart);
        assertEq(te.player, address(1));
    }


    // -------------------------------------
    // commit reverts if halted
    function testTranscriptCommitAndAllowExitUse() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowExitUse(id, exitUseOutcome(Locations.SideKind.South, 2));
    }

    function testFailTranscriptCommitAfterAllowAndHalt() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.allowAndHalt(id);
        f.commitExitUse(address(1), ExitUse(Locations.SideKind.South, 2));
    }

    function testFailTranscriptCommitAfterRejectAndHalt() public {

        f.start();

        TEID id = f.commitExitUse(address(1), ExitUse(Locations.SideKind.North, 1));
        f.rejectAndHalt(id);
        f.commitExitUse(address(1), ExitUse(Locations.SideKind.South, 2));
    }
}
