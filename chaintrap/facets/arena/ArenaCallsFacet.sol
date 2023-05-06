// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {ERC1155MetadataStorage} from "@solidstate/contracts/token/ERC1155/metadata/ERC1155Metadata.sol";
import {LibERC1155Arena} from "lib/erc1155/liberc1155arena.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "lib/arena/storage.sol";
import "lib/arena/accessors.sol";

import "lib/interfaces/IArenaCalls.sol";

contract ArenaCallsFacet is IArenaCalls {
    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    function lastGame() public view returns (GameID) {
        return GameID.wrap(ArenaStorage.layout().games.length - 1);
    }

    function playerRegistered(
        GameID gid,
        address p
    ) public view returns (bool) {
        return ArenaAccessors.game(gid).playerRegistered(p);
    }

    function gameStatus(GameID gid) public view returns (GameStatus memory) {
        Game storage g = ArenaAccessors.game(gid);
        GameStatus memory gs = g.status();

        uint256 id = LibERC1155Arena.idfrom(gid);
        gs.uri = ERC1155MetadataStorage.layout().tokenURIs[id];
        return gs;
    }

    /// @notice get the number of players currently known to the game (they may not be registered by the host yet)
    /// @param gid game id
    /// @return number of known players
    function playerCount(GameID gid) public view returns (uint8) {
        return ArenaAccessors.game(gid).playerCount();
    }

    /// @notice returns the numbered player record from storage
    /// @dev we account for the zeroth invalid player slot automatically
    /// @param gid gameid
    /// @param _iplayer player number. numbers range over 0 to playerCount() - 1
    /// @return player storage reference
    function player(
        GameID gid,
        uint8 _iplayer
    ) public view returns (Player memory) {
        return ArenaAccessors.game(gid).player(_iplayer);
    }

    function player(
        GameID gid,
        address _player
    ) public view returns (Player memory) {
        return ArenaAccessors.game(gid).player(_player);
    }
}
