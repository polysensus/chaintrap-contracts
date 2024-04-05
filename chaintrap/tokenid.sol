// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

error TypeRequirementNotMet(uint256 have, uint256 expect);
error TypeIDRequired(uint256 have);
error TypedNFTRequired(uint256 have);

// Use this to generate masks
// def shx(n, shift): return '0x' + '0' * (64 - len(hex(n<<shift)) + 2) + hex(n<<shift)[2:]

/// @notice Create a type token for a class of nfts. all type tokens are types
/// of nfts where each nft has an instance id for that type.
/// @param id a parameter just like in doxygen (must be followed by parameter name)
/// @return the return variables of a contract’s function state variable
function typeToken(uint256 id) pure returns (uint32) {
    return (uint32)(maskTypeField(id) >> 128);
}

function maskTypeField(uint256 id) pure returns (uint256) {
    return
        id & 0x000000000000000000000000ffffffff00000000000000000000000000000000;
}

/// @notice return the nft id. for a typed or un-typed nft
/// @dev the instance id for a typed nft and the id for an un-typed id live in the little end 128 bits
/// @param id any token id. if it is not an nft (typed or otherwise), the return value will be zero
/// @return token the return variables of a contract’s function state variable
function nftInstance(uint256 id) pure returns (uint128) {
    return uint128(id & 0xffffffffffffffffffffffffffffffff);
}

/// @notice return the token id. will return 0 if the id is an nft
function idToken(uint256 id) pure returns (uint32) {
    // explicit guard against use on an nft
    if (
        0x0 !=
        (id &
            0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
    ) return 0;
    return
        uint32(
            (id &
                0xffffffff00000000000000000000000000000000000000000000000000000000) >>
                (256 - 32)
        );
}

function isUntypedNFT(uint256 id) pure returns (bool) {
    return
        id <
        uint256(
            0x0000000000000000000000000000000100000000000000000000000000000000
        );
}

/// @notice Check if the id represents an nft type (not an instance of one)
/// @dev The token-type-id field is non-zero and the id instance field is zero
/// only for an id representing an nft token types.
/// @param id any token id
/// @return true if it is an nft type
function isNFTType(uint256 id) pure returns (bool) {
    return (0x0 !=
        (id &
            0x000000000000000000000000ffffffff00000000000000000000000000000000) &&
        0x0 ==
        (id &
            0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff));
}

/// @notice Check if the id represents an instance of an nft type (not the type itself)
/// @dev The token-type-id field is non-zero and the id instance field is not zero
/// only for an id representing an *instance* of an nft token type.
/// @param id any token id
/// @return true if it is an nft type
function isTypedNFT(uint256 id) pure returns (bool) {
    return (0x0 !=
        (id &
            0x000000000000000000000000ffffffff00000000000000000000000000000000) &&
        0x0 !=
        (id &
            0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff));
}

/// @notice require that the type of id matches the type of ty.
/// @param id is the type to check
/// @param ty is the type to check for. note this can also be *another* instance of the desired type.
function requireType(uint256 id, uint256 ty) pure {
    if (!checkType(id, ty))
        revert TypeRequirementNotMet(maskTypeField(id), maskTypeField(ty));
}

/// @notice check that the type of id matches the type of ty.
/// @param id is the type to check
/// @param ty is the type to check for. note this can also be *another* instance of the desired type.
/// @return true if the token type field of id matches the token type field of ty
function checkType(uint256 id, uint256 ty) pure returns (bool) {
    if (!isTypedNFT(id)) revert TypedNFTRequired(id);
    return (maskTypeField(id) == maskTypeField(ty));
}

library TokenID {
    // To permit types of nfts we need to have a type *and* an *instance* id.
    // ERC1155 specifically recomends (infact requires really) that this is
    // achieved by packing into a single uint256. ERC20's can have a type
    // without this arrangement, as they are fungible there can be no instance
    // state and hence no instance id.

    // we pack like this:

    // id's are 256 bit quantities. we use the split id scheme with mask to
    // reserve the low 96 bits for future use.
    //
    // In general the layout is this (big endian, least significant bit to the right most):
    //
    // |<-- 32--><-- 32 -->|<----- 32 ---->|<------------ 128 -------------->|
    // |        0          |      0        |           nft-id  (not typed)   |
    // |        0          | nft-type-id   |           nft-instance-id       |
    // | fungible|  resrvd |       0       |               0                 |
    //
    // un-typed nfts are all the values < 2^128
    // fungible tokens are all exact multiples of 2^(256-32). The nft-type-id and nft-instance-id fields are zero.
    // un-typed nfts have a token-type-id of 0, and a non-zero token-id. the little end (right)
    // typed nft ids are all > 2^128 AND mod (id, 128) != 0. typed nfts have a non-zero token-type-id and a non-zero token-id.

    uint256 constant ID_TYPE_BITS = 32;
    // remembering that words are big endian interpretation, put the type id at the little
    // end of the low 128 bytes.
    // put the type id at the little end (high address)
    uint256 constant ID_TYPE_SHIFT = 128;
    uint256 constant ID_TYPE_MASK = uint256(0xffffffff) << ID_TYPE_SHIFT;

    // No public facing nft type creation.
    uint256 constant GAME_TYPE = (1 << ID_TYPE_SHIFT);
    uint256 constant TRANSCRIPT_TYPE = (2 << ID_TYPE_SHIFT);
    uint256 constant FURNITURE_TYPE = (3 << ID_TYPE_SHIFT);
    uint256 constant GAME2_TYPE = (4 << ID_TYPE_SHIFT);
    uint256 constant LAST_FIXED_TYPE = FURNITURE_TYPE;
    uint256 constant MAX_FIXED_TYPE = (4096 << ID_TYPE_SHIFT);
}
