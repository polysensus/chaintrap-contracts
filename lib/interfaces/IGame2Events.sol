// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

interface IGame2Events {
    /// @dev emitted when a merkle root is initialised or changed
    event SetMerkleRoot(
        uint256 indexed id,
        bytes32 indexed label,
        bytes32 indexed root
    );
}
