const RESTING_MAGNITUDE_G = 1;

// Total acceleration in g, whatever the orientation of the watch.
export function magnitude({ x, y, z }) {
  return Math.hypot(x, y, z);
}

// At rest, an accelerometer reads only gravity, whatever the orientation of the watch.
export function isAtRest(accelerometer, toleranceG) {
  return Math.abs(magnitude(accelerometer) - RESTING_MAGNITUDE_G) <= toleranceG;
}
