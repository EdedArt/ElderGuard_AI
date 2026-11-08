import { describe, expect, it } from 'vitest';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { accelerometerMagnitude, nextAccelerometer } from '../src/core/generators/accelerometer.js';
import { nextBattery } from '../src/core/generators/battery.js';
import { nextGps } from '../src/core/generators/gps.js';
import { nextHeartRate } from '../src/core/generators/heartRate.js';

const STEPS = 5000;

// Mulberry32: a small seeded generator returning values in [0, 1).
function seededRandom(seed) {
  let state = seed;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describe('nextHeartRate', () => {
  const { restingMin, restingMax, noise } = telemetryConfig.heartRate;

  it('stays in the resting range with integer values and smooth changes', () => {
    const random = seededRandom(1);
    let current = 70;
    for (let i = 0; i < STEPS; i++) {
      const next = nextHeartRate(current, { random });
      expect(Number.isInteger(next)).toBe(true);
      expect(next).toBeGreaterThanOrEqual(restingMin);
      expect(next).toBeLessThanOrEqual(restingMax);
      expect(Math.abs(next - current)).toBeLessThanOrEqual(noise);
      current = next;
    }
  });

  it('actually moves and reaches both sides of its starting point', () => {
    const random = seededRandom(2);
    const seen = new Set();
    let current = 70;
    for (let i = 0; i < STEPS; i++) {
      current = nextHeartRate(current, { random });
      seen.add(current);
    }
    expect(Math.min(...seen)).toBeLessThan(70);
    expect(Math.max(...seen)).toBeGreaterThan(70);
  });

  it('returns to the resting range from an out-of-range value', () => {
    expect(nextHeartRate(180, { random: () => 0.5 })).toBe(restingMax);
    expect(nextHeartRate(20, { random: () => 0.5 })).toBe(restingMin);
  });

  it('is deterministic for the same random function', () => {
    const run = () => nextHeartRate(70, { random: seededRandom(7) });
    expect(run()).toBe(run());
  });
});

describe('nextAccelerometer', () => {
  const { rest, noise } = telemetryConfig.accelerometer;

  it('keeps the magnitude near 1g and each axis within the noise', () => {
    const random = seededRandom(3);
    for (let i = 0; i < STEPS; i++) {
      const reading = nextAccelerometer({ random });
      expect(Math.abs(accelerometerMagnitude(reading) - 1)).toBeLessThan(0.05);
      for (const axis of ['x', 'y', 'z']) {
        // The small margin absorbs float error: |0.98 - 1| is 0.020000000000000018.
        expect(Math.abs(reading[axis] - rest[axis])).toBeLessThanOrEqual(noise + 1e-9);
      }
    }
  });

  it('rounds to 2 decimals', () => {
    const random = seededRandom(4);
    for (let i = 0; i < 200; i++) {
      for (const value of Object.values(nextAccelerometer({ random }))) {
        expect(Number(value.toFixed(2))).toBe(value);
      }
    }
  });

  it('never produces negative zero', () => {
    const reading = nextAccelerometer({ random: () => 0.4999 });
    expect(Object.is(reading.x, -0)).toBe(false);
  });
});

describe('accelerometerMagnitude', () => {
  it('computes the vector length', () => {
    expect(accelerometerMagnitude({ x: 3, y: 4, z: 0 })).toBe(5);
  });
});

describe('nextGps', () => {
  const { baseLat, baseLng, drift, maxDrift, accuracyMin, accuracyMax } = telemetryConfig.gps;
  const start = { lat: baseLat, lng: baseLng, accuracy: accuracyMin, signal: true };
  // Coordinates are rounded to 6 decimals, which can land just past a limit.
  const tolerance = 0.000001;

  it('stays near the base with small steps and accuracy in range', () => {
    const random = seededRandom(5);
    let current = start;
    for (let i = 0; i < STEPS; i++) {
      const next = nextGps(current, { random });
      expect(Math.abs(next.lat - baseLat)).toBeLessThanOrEqual(maxDrift + tolerance);
      expect(Math.abs(next.lng - baseLng)).toBeLessThanOrEqual(maxDrift + tolerance);
      expect(Math.abs(next.lat - current.lat)).toBeLessThanOrEqual(drift + tolerance);
      expect(Math.abs(next.lng - current.lng)).toBeLessThanOrEqual(drift + tolerance);
      expect(next.accuracy).toBeGreaterThanOrEqual(accuracyMin);
      expect(next.accuracy).toBeLessThanOrEqual(accuracyMax);
      current = next;
    }
  });

  it('actually drifts', () => {
    const next = nextGps(start, { random: seededRandom(6) });
    expect([next.lat, next.lng]).not.toEqual([baseLat, baseLng]);
  });

  it('reports a signal, so a lost-signal override does not outlive its removal', () => {
    expect(nextGps({ ...start, signal: false }, { random: seededRandom(8) }).signal).toBe(true);
  });

  it('returns near the base from a far away position', () => {
    const next = nextGps({ ...start, lat: 50, lng: 50 }, { random: seededRandom(9) });
    expect(Math.abs(next.lat - baseLat)).toBeLessThanOrEqual(maxDrift + tolerance);
    expect(Math.abs(next.lng - baseLng)).toBeLessThanOrEqual(maxDrift + tolerance);
  });
});

describe('nextBattery', () => {
  const { startLevel, drainPerTick } = telemetryConfig.battery;

  it('decreases by the configured amount per tick', () => {
    const next = nextBattery({ level: 50, charging: false });
    expect(next.level).toBeCloseTo(50 - drainPerTick, 8);
    expect(next.charging).toBe(false);
  });

  it('does not accumulate floating point error', () => {
    let current = { level: startLevel, charging: false };
    for (let i = 0; i < 100; i++) current = nextBattery(current);
    expect(current.level).toBe(startLevel - 100 * drainPerTick);
  });

  it('never goes negative and stays at 0', () => {
    let current = { level: 0.005, charging: false };
    for (let i = 0; i < 5; i++) {
      current = nextBattery(current);
      expect(current.level).toBe(0);
    }
  });
});
