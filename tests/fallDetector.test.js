import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { createFallDetector, FALL_STATES } from '../src/core/fallDetector.js';

const { impactThresholdG, immobilityDurationMs, immobilityStartWindowMs, immobilityToleranceG } =
  fallDetectionConfig;

const SPIKE = { x: 0, y: 0, z: impactThresholdG + 1 };
const STILL = { x: 0, y: 0, z: 1 };
const MOVING = { x: 0, y: 0, z: 1 + immobilityToleranceG + 0.3 };

let detector;
let confirmed;

function feed(timestamp, accelerometer) {
  detector.process({ accelerometer, timestamp });
}

// Feeds a reading once per second over [from, to], like the telemetry engine does.
function feedEverySecond(from, to, accelerometer) {
  for (let timestamp = from; timestamp <= to; timestamp += 1000) feed(timestamp, accelerometer);
}

beforeEach(() => {
  detector = createFallDetector();
  confirmed = vi.fn();
  detector.onConfirmed(confirmed);
});

describe('real fall', () => {
  it('walks through every state and confirms once', () => {
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    feed(0, SPIKE);
    expect(detector.getState()).toBe(FALL_STATES.IMPACT);

    feed(1000, STILL);
    expect(detector.getState()).toBe(FALL_STATES.IMMOBILITY);
    expect(confirmed).not.toHaveBeenCalled();

    feed(1000 + immobilityDurationMs - 1, STILL);
    expect(detector.getState()).toBe(FALL_STATES.IMMOBILITY);
    expect(confirmed).not.toHaveBeenCalled();

    feed(1000 + immobilityDurationMs, STILL);
    expect(detector.getState()).toBe(FALL_STATES.CONFIRMED);
    expect(confirmed).toHaveBeenCalledTimes(1);
  });

  it('confirms with stillness in any orientation of the watch', () => {
    feed(0, SPIKE);
    feedEverySecond(1000, 1000 + immobilityDurationMs, { x: 1, y: 0, z: 0 });
    expect(confirmed).toHaveBeenCalledTimes(1);
  });

  it('accepts small noise within the tolerance', () => {
    feed(0, SPIKE);
    feed(1000, { x: 0, y: 0, z: 1 + immobilityToleranceG - 0.01 });
    feed(2000, { x: 0, y: 0, z: 1 - immobilityToleranceG + 0.01 });
    feed(1000 + immobilityDurationMs, STILL);
    expect(confirmed).toHaveBeenCalledTimes(1);
  });

  it('accepts a spike exactly at the threshold', () => {
    feed(0, { x: 0, y: 0, z: impactThresholdG });
    expect(detector.getState()).toBe(FALL_STATES.IMPACT);
  });

  it('stays confirmed and does not confirm again until reset', () => {
    feed(0, SPIKE);
    feedEverySecond(1000, 1000 + immobilityDurationMs, STILL);

    feed(10000, SPIKE);
    feedEverySecond(11000, 11000 + immobilityDurationMs, STILL);

    expect(detector.getState()).toBe(FALL_STATES.CONFIRMED);
    expect(confirmed).toHaveBeenCalledTimes(1);
  });
});

describe('false alarms', () => {
  it('does not confirm a spike followed by movement', () => {
    feed(0, SPIKE);
    feedEverySecond(1000, 1000 + immobilityStartWindowMs + immobilityDurationMs, MOVING);

    expect(detector.getState()).toBe(FALL_STATES.IDLE);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('returns to idle on any movement during immobility', () => {
    feed(0, SPIKE);
    feed(1000, STILL);
    feed(1000 + immobilityDurationMs - 1, MOVING);
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    feed(1000 + immobilityDurationMs, STILL);
    feed(1000 + immobilityDurationMs * 2, STILL);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('does not confirm stillness without a spike', () => {
    feedEverySecond(0, immobilityDurationMs * 3, STILL);

    expect(detector.getState()).toBe(FALL_STATES.IDLE);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('does not confirm a slow sit-down below the threshold', () => {
    const sitDown = [1, 1.2, 1.6, 2.1, impactThresholdG - 0.01, 1.8, 1.3, 1];
    sitDown.forEach((z, index) => feed(index * 500, { x: 0, y: 0, z }));
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    feedEverySecond(5000, 5000 + immobilityDurationMs * 2, STILL);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('does not confirm stillness that starts too late', () => {
    feed(0, SPIKE);
    feed(1000, MOVING);
    feed(immobilityStartWindowMs + 1, STILL);
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    feedEverySecond(immobilityStartWindowMs + 1001, immobilityDurationMs * 3, STILL);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('accepts stillness that starts at the very end of the window', () => {
    feed(0, SPIKE);
    feed(immobilityStartWindowMs, STILL);
    expect(detector.getState()).toBe(FALL_STATES.IMMOBILITY);
  });
});

describe('repeated impacts', () => {
  it('restarts the window from the latest impact', () => {
    feed(0, SPIKE);
    feed(2000, SPIKE);
    feed(2000 + immobilityStartWindowMs, STILL);
    expect(detector.getState()).toBe(FALL_STATES.IMMOBILITY);
  });

  it('treats a new impact during immobility as a new fall', () => {
    feed(0, SPIKE);
    feed(1000, STILL);
    feed(2000, SPIKE);
    expect(detector.getState()).toBe(FALL_STATES.IMPACT);

    feed(3000, STILL);
    feed(3000 + immobilityDurationMs - 1, STILL);
    expect(confirmed).not.toHaveBeenCalled();
    feed(3000 + immobilityDurationMs, STILL);
    expect(confirmed).toHaveBeenCalledTimes(1);
  });

  it('can detect a fall after an earlier false alarm', () => {
    feed(0, SPIKE);
    feed(1000, STILL);
    feed(2000, MOVING);

    feed(3000, SPIKE);
    feedEverySecond(4000, 4000 + immobilityDurationMs, STILL);
    expect(confirmed).toHaveBeenCalledTimes(1);
  });
});

describe('reset', () => {
  it.each([
    ['impact', () => feed(0, SPIKE)],
    [
      'immobility',
      () => {
        feed(0, SPIKE);
        feed(1000, STILL);
      },
    ],
    [
      'confirmed',
      () => {
        feed(0, SPIKE);
        feedEverySecond(1000, 1000 + immobilityDurationMs, STILL);
      },
    ],
  ])('returns to idle from %s', (_state, reach) => {
    reach();
    detector.reset();
    expect(detector.getState()).toBe(FALL_STATES.IDLE);
  });

  it('forgets a fall in progress', () => {
    feed(0, SPIKE);
    feed(1000, STILL);
    detector.reset();

    feedEverySecond(2000, 2000 + immobilityDurationMs, STILL);
    expect(confirmed).not.toHaveBeenCalled();
  });

  it('allows a new detection after a confirmed fall', () => {
    feed(0, SPIKE);
    feedEverySecond(1000, 1000 + immobilityDurationMs, STILL);
    detector.reset();

    feed(20000, SPIKE);
    feedEverySecond(21000, 21000 + immobilityDurationMs, STILL);
    expect(confirmed).toHaveBeenCalledTimes(2);
  });
});

describe('onConfirmed', () => {
  it('returns a function that removes the listener', () => {
    const listener = vi.fn();
    const unsubscribe = detector.onConfirmed(listener);
    unsubscribe();

    feed(0, SPIKE);
    feedEverySecond(1000, 1000 + immobilityDurationMs, STILL);
    expect(listener).not.toHaveBeenCalled();
    expect(confirmed).toHaveBeenCalledTimes(1);
  });
});

describe('configuration', () => {
  it('has the documented default values', () => {
    expect(fallDetectionConfig).toEqual({
      impactThresholdG: 2.5,
      immobilityToleranceG: 0.15,
      immobilityDurationMs: 5000,
      immobilityStartWindowMs: 3000,
      countdownSeconds: 10,
      urgentSeconds: 3,
    });
  });

  it('takes every threshold from the config it receives', () => {
    const custom = createFallDetector({
      config: {
        impactThresholdG: 5,
        immobilityToleranceG: 0.5,
        immobilityDurationMs: 100,
        immobilityStartWindowMs: 50,
      },
    });
    const listener = vi.fn();
    custom.onConfirmed(listener);

    custom.process({ accelerometer: { x: 0, y: 0, z: 4 }, timestamp: 0 });
    expect(custom.getState()).toBe(FALL_STATES.IDLE);

    custom.process({ accelerometer: { x: 0, y: 0, z: 5 }, timestamp: 0 });
    expect(custom.getState()).toBe(FALL_STATES.IMPACT);

    custom.process({ accelerometer: { x: 0, y: 0, z: 1.4 }, timestamp: 50 });
    expect(custom.getState()).toBe(FALL_STATES.IMMOBILITY);

    custom.process({ accelerometer: { x: 0, y: 0, z: 0.6 }, timestamp: 150 });
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
