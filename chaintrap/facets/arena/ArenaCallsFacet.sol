// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import { LibERC1155Arena } from "lib/erc1155/liberc1155arena.sol";
import "lib/game.sol";
import "lib/furnishings.sol";
import "lib/arena/storage.sol";
import "lib/arena/accessors.sol";



contract ArenaCallsFacet {

    using Transcripts for Transcript;
    using Games for Game;
    using Games for GameStatus;
    using Furnishings for Furniture;

    function lastGame() public view returns (GameID) {
        return GameID.wrap(ArenaStorage.layout().games.length - 1);
    }

    function playerRegistered(GameID gid, address p) public view returns (bool) {
        return ArenaAccessors.game(gid).playerRegistered(p);
    }

    function gameStatus(GameID id) public view returns (GameStatus memory) {
        Game storage g = ArenaAccessors.game(id);
        GameStatus memory gs = g.status();
        // XXX gs.uri = uri(g.id);
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
    function player(GameID gid, uint8 _iplayer) public view returns (Player memory) {
        return ArenaAccessors.game(gid).player(_iplayer);
    }

    function player(GameID gid, address _player) public view returns (Player memory) {
        return ArenaAccessors.game(gid).player(_player);
    }
}
