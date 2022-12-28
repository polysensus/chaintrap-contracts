// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.9 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "chaintrap/arena.sol";

contract ArenaTest is DSTest {
    using stdStorage for StdStorage;

    Vm private vm = Vm(HEVM_ADDRESS);
    StdStorage private stdstore;

    address master = address(1000);
    address master2 = address(2000);
    address player1 = address(1001);
    address player2 = address(1002);

    Arena private arena;
    Location[] private locs;
    uint16 nextExitID;
    uint256 blockNumberForLocationTokens;

    GameID g1;

    function setUp() public {
        // Deploy Map contract
        arena = new Arena();
        vm.prank(master, master);
        g1 = arena.createGame(2);
    }

    // proxy methods
    function load(RawLocation[] memory raw) public {
        arena.loadLocations(g1, raw);
    }
    function load(RawExit[] memory raw) public {
        arena.loadExits(g1, raw);
    }

    // loadLink because link with this type is an overload clash
    function loadLinks(RawLink[] memory raw) public {
        arena.loadLinks(g1, raw);
    }

    function load(TranscriptLocation[]memory locations) public {
        arena.loadTranscriptLocations(g1, locations);
    }

    function startGame(GameID gid) public {
        arena.startGame(gid);
    }

    function completeGame(GameID gid) public {
        arena.completeGame(gid);
    }


    function joinGame(address p, bytes calldata profile) public {
        arena._joinGame(g1, p, profile);
    }

    function playerCount(GameID gid) public view returns (uint8) {
        return arena.playerCount(gid);
    }

    function player(GameID gid, uint8 _iplayer) public view returns (Player memory) {
        return arena.player(gid, _iplayer);
    }
 
    function setStartLocation(address p, bytes32 startLocation, bytes memory sceneblob) public {
        arena.setStartLocation(g1, p, startLocation, sceneblob);
    }

    function playerRegistered(address p) public view returns (bool) {
        return arena.playerRegistered(g1, p);
    }

    function commitExitUse(GameID gid, address _player, ExitUse memory committed) public returns (TEID) {
        vm.prank(_player, _player);
        return arena.commitExitUse(gid, committed);
    }

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

        locations[0].sides = [bytes(hex"01"), hex"", hex"", hex"", hex"0001"];
        locations[1].sides = [bytes(hex"01"), hex"", hex"00020005", hex"000600070008", hex"0003"];
        locations[2].sides = [bytes(hex"01"), hex"", hex"0004", hex"", hex""];
        locations[3].sides = [bytes(hex"01"), hex"", hex"", hex"", hex"0009"];
        locations[4].sides = [bytes(hex"01"), hex"000a", hex"", hex"", hex"000b"];
        locations[5].sides = [bytes(hex"01"), hex"000d000e", hex"000c", hex"", hex""];
            
        load(locations);

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

        load(exits);

        RawLink[] memory links = new RawLink[](7);
        links[0] = RawLink(hex"0100010002"); // (1)-(2) ln1
        links[1] = RawLink(hex"0100030004"); // (3)-(4) ln2
        links[2] = RawLink(hex"0100050009"); // (5)-(9) ln3
        links[3] = RawLink(hex"010006000a"); // (6)-(10) ln4
        links[4] = RawLink(hex"010007000d"); // (7)-(13) ln5
        links[5] = RawLink(hex"010008000e"); // (8)-(14) ln6
        links[6] = RawLink(hex"01000b000c"); // (11)-(12) ln7

        loadLinks(links);
    }

    function locationToken(uint256 blockno, uint16 id) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(blockno, id));
    }

    function testLastGame() public {
        GameID lastId = arena.lastGame();
        assertEq(GameID.unwrap(lastId), GameID.unwrap(g1));
    }

    function testCreateGame() public {
        assertTrue(arena.gameValid(g1));
        vm.prank(master, master);
        GameID g2 = arena.createGame(2);
        assertTrue(arena.gameValid(g2));
    }

    function testRegisterPlayerArena() public {

        LocationID loc = LocationID.wrap(1);
        bytes32 token = locationToken(uint256(1), LocationID.unwrap(loc));
        TranscriptLocation []memory locations = new TranscriptLocation[](1);
        locations[0].token = token;
        locations[0].id = loc; 

        vm.prank(player1, player1);
        arena.joinGame(g1, bytes(""));

        vm.startPrank(master, master);
        arena.setStartLocation(g1, player1, token, bytes(""));

        arena.startGame(g1);
        arena.completeGame(g1);
        vm.stopPrank();

        loadDefaultMap();
        assertTrue(arena.playerRegistered(g1, player1));
    }

    function testPlayerCount() public {

        vm.prank(player1, player1);
        arena.joinGame(g1, bytes(""));
        uint8 count = arena.playerCount(g1);
        assertEq(count, 1);
    }

    function testPlayerCount2() public {

        vm.prank(player1, player1);
        arena.joinGame(g1, bytes(""));
        vm.prank(player2, player2);
        arena.joinGame(g1, bytes(""));
        uint8 count = arena.playerCount(g1);
        assertEq(count, 2);
    }

    function testGetUnregisteredPlayersByIndex() public {

        vm.prank(player1, player1);
        arena.joinGame(g1, bytes(""));
        vm.prank(player2, player2);
        arena.joinGame(g1, bytes(""));
        uint8 count = arena.playerCount(g1);
        for (uint i=0; i<count; i++) {
            Player memory p = arena.player(g1, uint8(i));
            assertEq(p.addr, address(uint160(1000+i+1)));
        }
    }

    function testDefaultMapLoads() public {
        vm.startPrank(master, master);
        arena.startGame(g1);
        arena.completeGame(g1);
        vm.stopPrank();
        loadDefaultMap();
    }

    function testCreateGameInitialisesTranscript() public {

        ExitUse memory u = ExitUse(Locations.SideKind.North, 1);
        vm.prank(player1, player1);
        arena.joinGame(g1, bytes(""));
        vm.prank(master, master);
        startGame(GameID.wrap(1));
        TEID eid = commitExitUse(GameID.wrap(1), player1, u);
        assertEq(TEID.unwrap(eid), uint16(1));
    }
}

