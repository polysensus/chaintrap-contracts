// SPDX-License-Identifier: UNLICENSED
/// @note without other arrangements to commit and reveal the linkages, the room
/// graph is completely exposed as soon as it is on chain.

pragma solidity =0.8.9;

type LocationID is uint16;
type LinkID is uint16;
type ExitID is uint16;
type KeyID is uint16;

LocationID constant invalidLocationID = LocationID.wrap(0);
LinkID constant invalidLinkID = LinkID.wrap(0);
ExitID constant invalidExitID = ExitID.wrap(0);
KeyID constant invalidKeyID = KeyID.wrap(0);

// These are all nft token type instances
type LocationModID is uint128;
LocationModID constant invalidLocationModID = LocationModID.wrap(0);

/// @title Link Defines a linkage between two locations.
/// @note A Link has a pair of Exits adjacent locations. A Door link can further
/// open opened and closed and locked. A lockable link accepts a key If a link
/// is locked with an undefined key, it cannot be unlocked (unless a key is
/// set). A link that isn't a door is always open and not locked.
struct Link {
    Links.Kind kind;
    /// exits identify the emergences into the adjacent locations
    ExitID[2] exits;
    // TODO: need to seperate the exits from the links so that the link state
    // can be on chain from the start but the exit linkages can be revealed
    // selectively by the game master.

    // Note: if key is invalidKeyID or 0 the link can not be unlocked once locked
    KeyID key;
    /// if autoclose, then the door closes behind after transiting
    bool autoclose;
    // state variables
    bool _locked;
    bool _open;
}

/// @title Exit defines a link emergence in a single location.
/// If the Exit is autoclose the door will close behind the player
struct Exit {
    LinkID link;
    LocationID loc;
}

error InvalidExit(uint16 exit);
/// InvalidLink raised if an invalid link id is provided
error InvalidLink();
/// @dev InvalidLinkExit is raised when the provided exit is not part of the expected link
error InvalidLinkExit(uint16 exit);
error ExitIsLocked();

library Exits {
    using Exits for Exit;
}

library Links {
    using Links for Link;

    /// The kind of the link.
    enum Kind {
        Undefined,
        Door,
        Archway,
        Invalid
    }

    /// ---------------------------
    /// @dev state changing methods

    /// @dev statefull traversing of a link, dealing with autoclose & locked states
    function traverse(
        Link storage self,
        ExitID egressVia
    ) internal returns (ExitID) {
        if (!self.open()) {
            revert ExitIsLocked();
        }

        ExitID ingressVia = self.otherExit(egressVia);
        if (self.autoclose) {
            // close it regardless of whether traversal opened it or not. this
            // forms the basis of a room trap
            self.close();
        }
        return ingressVia;
    }

    function lock(Link storage self) internal returns (bool) {
        if (!isLockable(self)) return false;
        self._locked = true;
        return true;
    }

    function unlock(Link storage self, KeyID key) internal returns (bool) {
        if (!isLockable(self)) return true;
        if (KeyID.unwrap(self.key) == KeyID.unwrap(invalidKeyID)) return false;
        if (KeyID.unwrap(self.key) != KeyID.unwrap(key)) return false;

        self._locked = false;
        return true;
    }

    function open(Link storage self) internal returns (bool) {
        if (!isClosable(self)) return true;

        if (self._locked) {
            return false;
        }
        self._open = true;
        return true;
    }

    function close(Link storage self) internal returns (bool) {
        if (!isClosable(self)) return true;

        // Note: we can close a locked door. And then it can't be opened with `open'
        self._open = false;
        return true;
    }

    /// ---------------------------
    /// @dev state reading methods

    /// tryotherExit returns the id of the Exit on the otherside if the given *Exit* id
    function tryotherExit(
        Link storage self,
        ExitID id
    ) internal view returns (ExitID) {
        if (ExitID.unwrap(id) == ExitID.unwrap(invalidExitID)) {
            return invalidExitID;
        }
        if (ExitID.unwrap(self.exits[0]) == ExitID.unwrap(id)) {
            return self.exits[1];
        }
        if (ExitID.unwrap(self.exits[1]) == ExitID.unwrap(id)) {
            return self.exits[0];
        }
        return invalidExitID;
    }

    /// tryotherExit returns the id of the Exit on the otherside if the given Exit *index*
    function tryotherExit(
        Link storage self,
        uint8 i
    ) internal view returns (ExitID) {
        if (i == 0) {
            return self.exits[1];
        }
        if (i == 1) {
            return self.exits[0];
        }
        return invalidExitID;
    }

    function otherExit(
        Link storage self,
        ExitID id
    ) internal view returns (ExitID) {
        ExitID other = tryotherExit(self, id);
        if (ExitID.unwrap(invalidExitID) == ExitID.unwrap(other)) {
            revert InvalidLinkExit(ExitID.unwrap(id));
        }
        return other;
    }

    /// isLockable returns true if the link is lockable. The state variable
    /// locked is ignored unless the link is lockable
    function isLockable(Link storage self) internal view returns (bool) {
        return self.kind == Kind.Door;
    }

    /// isClosable returns true if the link can be closed. The state variable
    /// open is ignored if this method returns false
    function isClosable(Link storage self) internal view returns (bool) {
        return self.kind == Kind.Door;
    }

    /// isEnterable returns true if the link is open for transiting. If the link
    /// is not closable it is always enterable.
    function isEnterable(Link storage self) internal view returns (bool) {
        if (!isClosable(self)) return true;

        /// Subtlety - a locked door may be locked and open. If so, the lock has
        /// no effect until the door is closed. This makes a kind of trap possible.
        return self._open;
    }

    function isOpen(Link storage self) internal view returns (bool) {
        if (!isClosable(self)) return true;

        return self._open;
    }

    function isLocked(Link storage self) internal view returns (bool) {
        return self._locked;
    }
}
