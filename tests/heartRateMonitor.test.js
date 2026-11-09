import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { heartRateAnomalyConfig } from '../src/config/heartRateAnomaly.config.js';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';

const TICK = telemetryConfig.tickIntervalMs;
const HIGH_ALERT = 'high-heart-rate';
const TIME_TO_WARN = heartRateAnomalyConfig.sustainedDurationMs + TICK;
const STILL = { x: 0, y: 0, z: 1 };
const MOVING = { x: 0.4, y: 0.5, z: 1.4 };
const SPIKE = { x: 2.5, y: 1.8, z: 3.2 };

let device;
let anomaly;
let resolved;

const status = () => device.store.getState().deviceStatus;

function holdHighRate() {
  device.engine.setOverride('heartRate', 140);
  device.engine.setOverride('accelerometer', STILL);
}

beforeEach(() => {
  vi.useFakeTimers();
  device = createDevice({ createAudioContext: () => null });
  anomaly = vi.fn();
  resolved = vi.fn();
  device.heartRateMonitor.on('heartRate:anomaly', anomaly);
  device.heartRateMonitor.on('heartRate:resolved', resolved);
  device.start();
});

afterEach(() => {
  device.engine.stop();
  device.fall.cancel();
  vi.useRealTimers();
});

describe('warning', () => {
  it('starts with no health alert', () => {
    expect(status().healthAlert).toBeNull();
  });

  it('emits the anomaly and sets the health alert once the rate has stayed high', () => {
    holdHighRate();
    vi.advanceTimersByTime(heartRateAnomalyConfig.sustainedDurationMs - 1);
    expect(anomaly).not.toHaveBeenCalled();
    expect(status().healthAlert).toBeNull();

    vi.advanceTimersByTime(TICK);
    expect(anomaly).toHaveBeenCalledTimes(1);
    expect(anomaly.mock.calls[0][0]).toMatchObject({ heartRate: 140 });
    expect(anomaly.mock.calls[0][0].timestamp).toEqual(expect.any(Number));
    expect(status().healthAlert).toBe(HIGH_ALERT);
  });

  it('leaves the device monitoring', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);
    expect(status().mode).toBe('monitoring');
  });

  it('keeps the alert while the condition lasts, and does not repeat the event', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN + TICK * 20);
    expect(anomaly).toHaveBeenCalledTimes(1);
    expect(status().healthAlert).toBe(HIGH_ALERT);
  });

  it('survives the ticks of the engine, which write the rest of the device status', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);
    const before = status().lastUpdate;
    vi.advanceTimersByTime(TICK);
    expect(status().lastUpdate).toBeGreaterThan(before);
    expect(status().healthAlert).toBe(HIGH_ALERT);
  });
});

describe('resolving', () => {
  beforeEach(() => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);
  });

  it('clears the alert when the rate drops', () => {
    device.engine.setOverride('heartRate', 70);
    expect(status().healthAlert).toBeNull();
    expect(resolved).toHaveBeenCalledTimes(1);
  });

  it('clears the alert when movement resumes', () => {
    device.engine.setOverride('accelerometer', MOVING);
    expect(status().healthAlert).toBeNull();
    expect(resolved).toHaveBeenCalledTimes(1);
  });

  it('reset clears the alert, reporting nothing', () => {
    device.heartRateMonitor.reset();
    expect(status().healthAlert).toBeNull();
    expect(resolved).not.toHaveBeenCalled();
  });
});

describe('independence from the fall flow', () => {
  const { immobilityDurationMs, countdownSeconds } = fallDetectionConfig;

  it('does not disturb a fall, which still counts down and reaches the SOS', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);

    device.engine.setOverride('accelerometer', SPIKE);
    device.engine.setOverride('accelerometer', STILL);
    vi.advanceTimersByTime(immobilityDurationMs + TICK);
    expect(status().mode).toBe('fall-countdown');
    expect(device.countdown.isRunning()).toBe(true);

    vi.advanceTimersByTime(countdownSeconds * 1000);
    expect(status().mode).toBe('sos');
  });

  it('keeps evaluating during a countdown, and sets its alert without ending it', () => {
    device.engine.setOverride('accelerometer', SPIKE);
    device.engine.setOverride('accelerometer', STILL);
    vi.advanceTimersByTime(immobilityDurationMs + TICK);
    expect(status().mode).toBe('fall-countdown');

    device.engine.setOverride('heartRate', 140);
    vi.advanceTimersByTime(heartRateAnomalyConfig.sustainedDurationMs);

    expect(status().healthAlert).toBe(HIGH_ALERT);
    expect(status().mode).toBe('fall-countdown');
    expect(device.countdown.isRunning()).toBe(true);
  });

  it('keeps its alert when a fall is cancelled', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);
    device.engine.setOverride('accelerometer', SPIKE);
    device.engine.setOverride('accelerometer', STILL);
    vi.advanceTimersByTime(heartRateAnomalyConfig.sustainedDurationMs);
    expect(status().mode).toBe('fall-countdown');

    device.fall.cancel();
    expect(status().mode).toBe('monitoring');
    expect(status().healthAlert).toBe(HIGH_ALERT);
  });

  it('a manual SOS leaves the health alert alone', () => {
    holdHighRate();
    vi.advanceTimersByTime(TIME_TO_WARN);
    device.sos.trigger({ reason: 'manual' });
    device.sos.cancel();
    expect(status().healthAlert).toBe(HIGH_ALERT);
  });
});
