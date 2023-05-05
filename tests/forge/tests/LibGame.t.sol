// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {GameIsInitialised} from "lib/game2.sol";
import {LibGame, Game2, Game2InitArgs} from "lib/game2.sol";

contract Game2Factory {

    Game2[] games;

    function pushGame() public {
        _pushGame();
    }

    function _pushGame() internal returns (Game2 storage) {
        uint256 i = games.length;
        games.push();
        return games[i];
    }


    function currentGame() internal view returns (Game2 storage) {
        return games[games.length - 1];
    }

    //--- LibGame public forwarders
    // These are required to make calldata work
    function _init(Game2InitArgs calldata args) public {
        LibGame._init(currentGame(), args);
    }
    function checkRoot(bytes32[] calldata proof, bytes32 label, bytes32 node) public view returns (bool) {
        return LibGame.checkRoot(currentGame(), proof, label, node);
    }
}

contract Game2Test is DSTest {
    using LibGame  for Game2;
    using stdStorage for StdStorage;

    Vm private vm = Vm(HEVM_ADDRESS);

    StdStorage private stdstore;

    Game2Factory f;

    constructor() {
        f = new Game2Factory();
    }

    function setUp() public {
        f.pushGame(); // make zero'th inaccessible
    }

    function minimalyValidInitArgs() internal pure returns (Game2InitArgs memory) {
        return Game2InitArgs({
            gid: 1,
            rootLabels:new bytes32[](1),
            roots:new bytes32[](1)}
            );
    }

    function test__init_RevertInitialiseTwice() public {
        f.pushGame();
        f._init(minimalyValidInitArgs());

        vm.expectRevert(GameIsInitialised.selector);
        f._init(minimalyValidInitArgs());
    }

    function test__init_RevertMoreRootsThanLabels() public {
        f.pushGame();

        vm.expectRevert(stdError.indexOOBError); // array out of bounds
        f._init(Game2InitArgs({
            gid: 1,
            rootLabels:new bytes32[](1),
            roots:new bytes32[](2)}
            ));
    }

    function test__init_NoRevertFewerRootsThanLabels() public {
        f.pushGame();

        f._init(Game2InitArgs({
            gid: 1,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](1)}
            ));
    }

    function test__init_EmitSetMerkleRoot() public {
        f.pushGame();

        vm.expectEmit(true, true, true, true);

        // Should get one emit for each root
        emit LibGame.SetMerkleRoot(1, "", "");
        emit LibGame.SetMerkleRoot(1, "", "");

        f._init(Game2InitArgs({
            gid: 1,
            rootLabels:new bytes32[](2),
            roots:new bytes32[](2)}
            ));
    }

    function test_checkRoot() public {

        // generated from map02.json using chaintrap-arenastate/cli.js
        //   maptrieproof tests/data/maps/map02.json 1
        // {
        //      "value":[[8,3,0],[0,1,0]],
        //      "leaf":"0x89b28fc7a697b39897740df65cec519eaf9c56ce8f5a88d04e8bc976a91703e9",
        //      "root":"0x141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562",
        //      "proof":[
        //          "0x840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f7",
        //          "0xc6abef3208a3433ad2e81daeee8d77789e2abc6ccb45db41fcf2e85c14ed2834",
        //          "0x98541c3fd2ce651a452bb8f0d4812fa4ac0231c9d1c0eb7d7353949da4289725",
        //          "0x54149a09f84ed0d33400271f1c66d5bac2299cd6c5695194c77c1d6165f51fbe",
        //          "0x8c4e03aa1a345609a3550b6a1d33de710ecd0398f38c992344b78b0b4aaf4ff7"
        //     ]
        //  }
        bytes32 leaf = hex"89b28fc7a697b39897740df65cec519eaf9c56ce8f5a88d04e8bc976a91703e9";
        bytes32 root = hex"141d529a677497c1e718dcaea00c5ee952720942c8a43e9fda2c38ab24cfb562";
        bytes32[] memory proof = new bytes32[](5);
        proof[0] = hex"840af2c72ba2afe9962febbc9b5b8f2eb98fcf3c22193be8fa299e5add46b2f7";
        proof[1] = hex"c6abef3208a3433ad2e81daeee8d77789e2abc6ccb45db41fcf2e85c14ed2834";
        proof[2] = hex"98541c3fd2ce651a452bb8f0d4812fa4ac0231c9d1c0eb7d7353949da4289725";
        proof[3] = hex"54149a09f84ed0d33400271f1c66d5bac2299cd6c5695194c77c1d6165f51fbe";
        proof[4] = hex"8c4e03aa1a345609a3550b6a1d33de710ecd0398f38c992344b78b0b4aaf4ff7";

        f.pushGame();
        bytes32[] memory rootLabels = new bytes32[](1);
        bytes32[] memory roots = new bytes32[](1);
        rootLabels[0]=hex"aaaa";
        roots[0] = root;
        f._init(Game2InitArgs({
            gid: 1,
            rootLabels:rootLabels,
            roots:roots}
            ));

        bool result = f.checkRoot(proof, hex"aaaa", leaf);
        assertTrue(result);

        // check we get a result, but a false one, for a bad root name
        result = f.checkRoot(proof, hex"bbbb", leaf);
        assertTrue(!result);
    }

}