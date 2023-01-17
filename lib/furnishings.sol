// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.9;
import "lib/furnishings.sol";

error FurnitureEffectsMissingValues();

type FurnitureID is uint256;

FurnitureID constant invalidFurnitureID = FurnitureID.wrap(0);

struct Furniture {
    Furnishings.Kind kind;
    Furnishings.Effect []effects;
    // uint256 []values;
}

/* mint a locationmod for the main exit to the player when the game is created
bind it to the game for ever.
each new game session allows the exit to be moved.
if the game is transfered, the main exit token goes with it ?
*/

library Furnishings {

    /// @notice The kind of furnishing. Note that 0 is undefined
    enum Kind {Undefned, Finish, Trap, Boon, Invalid }
    /// @notice if the furnishing is used the effect that will have
    enum Effect {Undefined, Victory, Death, FreeLife, Invalid }

    /// --------------------------
    /// @dev state reading methods - location mods

    /// --------------------------
    function load(Furniture storage self, Furniture calldata subject) internal {
        // if (subject.effects.length != subject.values.length)
        //    revert FurnitureEffectsMissingValues();

        self.kind = subject.kind;
        if (subject.effects.length > 0) {
            self.effects = new Furnishings.Effect[](subject.effects.length);
            for (uint i = 0; i < subject.effects.length; i ++)
                self.effects[i] = subject.effects[i];
                // self.values[i] = subject.values[i];
        }
    }
}