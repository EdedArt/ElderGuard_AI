import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { heartRateAnomalyConfig } from '../src/config/heartRateAnomaly.config.js';
import {
  ANOMALY_STATES,
  createHeartRateAnomalyDetector,
} from '../src/core/heartRateAnomalyDetector.js';

const { bpmThreshold, stillnessToleranceG, sustainedDurationMs } = heartRateAnomalyConfig;
const HIGH = bpmThreshold + 20;
const STILL = { x: 0, y: 0, z: 1 };
const MOVING = { x: 0.4, y: 0.5, z: 1.4 };

let detector;
let warned;
let resolved;
let time;

function sample(heartRate, accelerometer = STILL, elapsedMs = 1000) {
  time += elapsedMs;
  detector.process({ heartRate, accelerometer, timestamp: time });
}

function reachWarning() {
  sample(HIGH);
  sample(HIGH, STILL, sustainedDurationMs);
}

beforeEach(() => {
  time = 0;
  detector = createHeartRateAnomalyDetector();
  warned = vi.fn();
  resolved = vi.fn();
  detector.onWarning(warned);
  detector.onResolved(resolved);
});

describe('configuration', () => {
  it('has the agreed values, sharing the stillness tolerance of the fall detector', () => {
    expect(bpmThreshold).toBe(120);
    expect(sustainedDurationMs).toBe(8000);
    expect(stillnessToleranceG).toBe(fallDetectionConfig.immobilityToleranceG);
  });
});

describe('reaching the warning', () => {
  it('starts normal', () => {
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
  });

  it('counts the time from the first high sample', () => {
    sample(HIGH);
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);

    sample(HIGH, STILL, sustainedDurationMs - 1);
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);
    expect(warned).not.toHaveBeenCalled();

    sample(HIGH, STILL, 1);
    expect(detector.getState()).toBe(ANOMALY_STATES.WARNING);
    expect(warned).toHaveBeenCalledTimes(1);
  });

  it('warns only once while the condition lasts', () => {
    reachWarning();
    for (let index = 0; index < 20; index += 1) sample(HIGH);
    expect(warned).toHaveBeenCalledTimes(1);
  });

  it('needs the heart rate above the threshold, not at it', () => {
    for (let index = 0; index < 20; index += 1) sample(bpmThreshold);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);

    sample(bpmThreshold + 1);
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);
  });

  it('has its state updated by the time listeners are told', () => {
    const seen = [];
    detector.onWarning(() => seen.push(detector.getState()));
    reachWarning();
    expect(seen).toEqual([ANOMALY_STATES.WARNING]);
  });
});

describe('what does not warn', () => {
  it('ignores normal heart rates', () => {
    for (let index = 0; index < 30; index += 1) sample(70);
    expect(warned).not.toHaveBeenCalled();
  });

  it('ignores a brief spike, and starts the count over after it', () => {
    sample(HIGH);
    sample(HIGH, STILL, sustainedDurationMs - 1000);
    sample(70);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);

    sample(HIGH);
    sample(HIGH, STILL, sustainedDurationMs - 1);
    expect(warned).not.toHaveBeenCalled();
  });

  it('ignores a fast heart while moving, however long it lasts', () => {
    for (let index = 0; index < 30; index += 1) sample(HIGH, MOVING);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
    expect(warned).not.toHaveBeenCalled();
  });

  it('starts the count over if movement interrupts it', () => {
    sample(HIGH);
    sample(HIGH, STILL, sustainedDurationMs - 1000);
    sample(HIGH, MOVING);
    sample(HIGH);
    sample(HIGH, STILL, sustainedDurationMs - 1);
    expect(warned).not.toHaveBeenCalled();
  });

  it('treats the edge of the tolerance as resting, and past it as moving', () => {
    const atEdge = { x: 0, y: 0, z: 1 + stillnessToleranceG };
    const pastEdge = { x: 0, y: 0, z: 1 + stillnessToleranceG + 0.01 };

    sample(HIGH, atEdge);
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);
    sample(HIGH, pastEdge);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
  });

  it('counts any orientation as resting, since only the magnitude matters', () => {
    sample(HIGH, { x: 0.6, y: 0.8, z: 0 });
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);
  });
});

describe('going back to normal', () => {
  it('resolves when the heart rate drops', () => {
    reachWarning();
    sample(70);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
    expect(resolved).toHaveBeenCalledTimes(1);
  });

  it('resolves when movement resumes', () => {
    reachWarning();
    sample(HIGH, MOVING);
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
    expect(resolved).toHaveBeenCalledTimes(1);
  });

  it('does not report resolved if no warning had been given', () => {
    sample(HIGH);
    sample(70);
    expect(resolved).not.toHaveBeenCalled();
  });

  it('can warn again, after the full time', () => {
    reachWarning();
    sample(70);
    reachWarning();
    expect(warned).toHaveBeenCalledTimes(2);
  });
});

describe('reset', () => {
  it('goes back to normal without reporting anything', () => {
    reachWarning();
    detector.reset();
    expect(detector.getState()).toBe(ANOMALY_STATES.NORMAL);
    expect(resolved).not.toHaveBeenCalled();
  });

  it('forgets the time already counted', () => {
    sample(HIGH);
    sample(HIGH, STILL, sustainedDurationMs - 1000);
    detector.reset();
    sample(HIGH);
    expect(detector.getState()).toBe(ANOMALY_STATES.ELEVATED);
    expect(warned).not.toHaveBeenCalled();
  });
});

describe('other thresholds', () => {
  it('takes them from its configuration', () => {
    const critical = createHeartRateAnomalyDetector({
      config: { bpmThreshold: 160, sustainedDurationMs: 2000, stillnessToleranceG },
    });
    const listener = vi.fn();
    critical.onWarning(listener);

    critical.process({ heartRate: 150, accelerometer: STILL, timestamp: 0 });
    critical.process({ heartRate: 150, accelerometer: STILL, timestamp: 5000 });
    expect(listener).not.toHaveBeenCalled();

    critical.process({ heartRate: 170, accelerometer: STILL, timestamp: 6000 });
    critical.process({ heartRate: 170, accelerometer: STILL, timestamp: 8000 });
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
