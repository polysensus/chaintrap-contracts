import { Locations } from './locations.mjs'
export { Locations };
import { RawLocation } from './locations.mjs'
export { RawLocation };

import {RawLink, RawExit} from './exitlinks.mjs'
export {RawLink, RawExit}

import { TranscriptLocation } from './transcript.mjs'
export { TranscriptLocation };

import { Game } from './game.mjs';
export { Game };

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