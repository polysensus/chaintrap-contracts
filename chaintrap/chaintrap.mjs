import { Locations } from './locations.mjs'
export { Locations };
import { Location } from './locations.mjs'
export { Location };

import { Link, Exit } from './exitlinks.mjs'
export { Link, Exit }

import { TranscriptLocation } from './transcript.mjs'
export { TranscriptLocation };

import { Game } from './game.mjs';
export { Game };

import { TXProfiler } from './txprofile.mjs'
export { TXProfiler }

function locationKinds() {
    return {
        ROOM: Locations.Kind.Room,
        INTERSECTION: Locations.Kind.Intersection,
        CORRIDOR: Locations.Kind.CORRIDOR
    }
}

export { locationKinds };

function locationSides() {
  return {
    NORTH: Locations.SideKind.North,
    WEST: Locations.SideKind.West,
    EAST: Locations.SideKind.East,
    SOUTH: Locations.SideKind.South
  }
}

export { locationSides };