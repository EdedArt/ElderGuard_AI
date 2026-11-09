export const telemetryConfig = {
  tickIntervalMs: 1000,
  heartRate: {
    restingMin: 60, // BPM
    restingMax: 80, // BPM
    noise: 2, // Largest change per tick, in BPM
  },
  accelerometer: {
    rest: { x: 0, y: 0, z: 1 }, // g
    noise: 0.02, // Largest deviation per axis, in g
  },
  gps: {
    baseLat: 4.6097, // Sample location: Bogotá, Colombia
    baseLng: -74.0817,
    drift: 0.00002, // Largest change per tick, in degrees (about 2 m)
    maxDrift: 0.0002, // Largest distance from the base, in degrees (about 22 m)
    accuracyMin: 3, // Meters
    accuracyMax: 8, // Meters
  },
  battery: {
    startLevel: 100, // Percent
    drainPerTick: 0.01, // Percent
    lowLevel: 20, // Percent, inclusive
    criticalLevel: 10, // Percent, inclusive
  },
};
