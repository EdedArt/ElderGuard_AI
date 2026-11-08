export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

export function roundTo(value, decimals) {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor + 0; // Adding 0 turns -0 into 0.
}

// A value in [-max, max), for a random function returning values in [0, 1).
export function randomOffset(random, max) {
  return (random() * 2 - 1) * max;
}
