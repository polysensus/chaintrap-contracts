import { Locations } from "./locations.js";
export { Locations };
import { Location } from "./locations.js";
export { Location };

import { Link, Exit } from "./exitlinks.js";
export { Link, Exit };

import { TranscriptLocation } from "./transcript.js";
export { TranscriptLocation };

import { Game } from "./game.js";
export { Game };

import { TXProfiler } from "./txprofile.js";
export { TXProfiler };

function locationKinds() {
  return {
    ROOM: Locations.Kind.Room,
    INTERSECTION: Locations.Kind.Intersection,
    CORRIDOR: Locations.Kind.CORRIDOR,
  };
}

export { locationKinds };

export const NORTH = Locations.SideKind.North;
export const WEST = Locations.SideKind.West;
export const EAST = Locations.SideKind.East;
export const SOUTH = Locations.SideKind.South;

function locationSides() {
  return {
    NORTH: Locations.SideKind.North,
    WEST: Locations.SideKind.West,
    EAST: Locations.SideKind.East,
    SOUTH: Locations.SideKind.South,
  };
}

export { locationSides };
