// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import "./storage.sol";

error InvalidGame(uint256 id);

library ArenaAccessors {
    /// @dev the only
    function _index(GameID id) internal view returns (bool, uint256) {
        ArenaStorage.Layout storage s = ArenaStorage.layout();

        // The length of games & trans are only changed by createGame
        // so we do not repeat the length consistency checks here.
        if (s.games.length == 0) {
            return (false, 0);
        }

        uint256 i = GameID.unwrap(id);
        if (i == 0) {
            return (false, 0);
        }
        if (i >= s.games.length) {
            return (false, 0);
        }
        return (true, i);
    }

    function _trans(
        GameID gid,
        bool requireOpen
    ) internal view returns (Transcript storage) {
        (, Transcript storage t) = _gametrans(gid, requireOpen);
        return t;
    }

    function _gametrans(
        GameID gid,
        bool requireOpen
    ) internal view returns (Game storage, Transcript storage) {
        (bool ok, uint256 ig) = _index(gid);
        if (!ok) {
            revert InvalidGame(ig);
        }

        ArenaStorage.Layout storage s = ArenaStorage.layout();

        TID tid = s.gid2tid[gid];
        uint256 it = TID.unwrap(tid);
        Game storage g = s.games[ig];

        if (it == 0 || it >= s.transcripts.length) {
            revert InvalidTID(it);
        }

        if (requireOpen) {
            if (!g.started) {
                revert GameNotStarted();
            }
            if (g.completed) {
                revert GameComplete();
            }
        }

        return (g, s.transcripts[it]);
    }

    function game(GameID id) internal view returns (Game storage) {
        (bool ok, uint256 i) = _index(id);
        if (!ok) {
            revert InvalidGame(i);
        }
        return ArenaStorage.layout().games[i];
    }
}
