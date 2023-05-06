// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error GameIsInitialised();
error InvalidProof();

struct Game2 {
    uint256 gid;
    LibGame.GameState state;
    /// @dev roots is a mapping from labels to roots. labels can be
    /// keccak(string|bytes) or any value that packs into bytes32. We don't use
    /// strings or bytes because we emit events on change. And the dynamic types
    /// would be hashed anyway then.
    mapping(bytes32 => bytes32) roots;

    // TODO: consider a nonce per player, and consider having no nonce at all
    // (the blockchain gives us a total ordering anyway) uint256 moveNonce;
}

struct Game2InitArgs {
    /// @dev game id
    uint256 gid;
    /// @dev a rootLabel identifies a root. it can be a string (eg a name), a
    /// token id, an address whatever, it must be keccak hashed if it is a
    /// dynamic type (string or bytes). Note: we don't do bytes or string
    /// because those can't be indexed in log topics.
    bytes32[] rootLabels;
    /// @dev roots is an array of merkle tree roots. each is associated with an entry in rootLabels.
    bytes32[] roots;
}

library LibGame {
    enum GameState {
        Unknown,
        Initialised,
        Started,
        Complete
    }

    // NOTE: These are duplicated in facets - this is the only way to expose the abi to ethers.js
    event SetMerkleRoot(
        uint256 indexed gid,
        bytes32 indexed label,
        bytes32 indexed root
    );

    /// @dev initialise game storage
    function _init(Game2 storage self, Game2InitArgs calldata args) internal {
        if (self.state > GameState.Unknown) revert GameIsInitialised();
        self.gid = args.gid;
        self.state = GameState.Initialised;

        for (uint i = 0; i < args.roots.length; i++) {
            // Note: solidity reverts for array out of bounds so we don't check for array length equivelence.
            self.roots[args.rootLabels[i]] = args.roots[i];
            emit SetMerkleRoot(self.gid, args.rootLabels[i], args.roots[i]);
        }
    }

    /// @dev checkRoot returns true if the proof for the lableled root is correct
    function checkRoot(
        Game2 storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view returns (bool) {
        // if (self.roots[label]==0) revert("LibGame# checkRoot: label not found");
        return MerkleProof.verifyCalldata(proof, self.roots[label], node);
    }

    /// @dev verifyRoot reverts with InvalidProof if the proof for the lableled root is incorrect.
    function verifyRoot(
        Game2 storage self,
        bytes32[] calldata proof,
        bytes32 label,
        bytes32 node
    ) internal view {
        if (!checkRoot(self, proof, label, node)) revert InvalidProof();
    }
}
