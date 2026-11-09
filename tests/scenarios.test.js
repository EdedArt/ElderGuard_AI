import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { criticalHeartRateConfig } from '../src/config/heartRateAnomaly.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { magnitude } from '../src/core/magnitude.js';
import { createScenarioRunner } from '../src/core/scenarioRunner.js';
import { scenarios } from '../src/simulator/scenarios.js';

const { immobilityToleranceG, impactThresholdG } = fallDetectionConfig;
const TICK = telemetryConfig.tickIntervalMs;
const LONG_WAIT = 30000;

let device;
let runner;
let detected;

const state = () => device.store.getState();
const lastAt = ({ steps }) => Math.max(...steps.map(({ atMs }) => atMs));

beforeEach(() => {
  vi.useFakeTimers();
  device = createDevice({ createAudioContext: () => null });
  runner = createScenarioRunner({ engine: device.engine });
  detected = vi.fn();
  device.fall.on('fall:detected', detected);
  device.start();
});

afterEach(() => {
  device.engine.stop();
  runner.stop();
  device.fall.cancel();
  vi.useRealTimers();
});

describe('fall', () => {
  it('goes through impact and immobility, and the real detector confirms it', () => {
    runner.run(scenarios.fall);
    expect(device.fall.getDetectorState()).toBe('impact');

    vi.advanceTimersByTime(TICK * 2);
    expect(device.fall.getDetectorState()).toBe('immobility');
    expect(detected).not.toHaveBeenCalled();

    vi.advanceTimersByTime(lastAt(scenarios.fall));
    expect(detected).toHaveBeenCalledTimes(1);
    expect(state().deviceStatus.mode).toBe('fall-countdown');
  });

  it.each([0, 1, 250, 500, 999])('is detected when started %i ms after a tick', (offsetMs) => {
    vi.advanceTimersByTime(offsetMs);
    runner.run(scenarios.fall);
    vi.advanceTimersByTime(lastAt(scenarios.fall));
    expect(detected).toHaveBeenCalledTimes(1);
  });

  it('hands the sensor back after the stillness has been confirmed', () => {
    runner.run(scenarios.fall);
    vi.advanceTimersByTime(lastAt(scenarios.fall));
    expect(runner.isRunning()).toBe(false);

    const readings = new Set();
    device.store.subscribe(({ accelerometer }) => readings.add(JSON.stringify(accelerometer)));
    vi.advanceTimersByTime(TICK * 5);
    expect(readings.size).toBeGreaterThan(1);
  });
});

describe('stumble', () => {
  it('registers the impact but never alerts', () => {
    runner.run(scenarios.stumble);
    expect(device.fall.getDetectorState()).toBe('impact');

    vi.advanceTimersByTime(LONG_WAIT);
    expect(detected).not.toHaveBeenCalled();
    expect(state().deviceStatus.mode).toBe('monitoring');
    expect(device.fall.getDetectorState()).toBe('idle');
  });

  it.each([0, 1, 250, 500, 999])('does not alert when started %i ms after a tick', (offsetMs) => {
    vi.advanceTimersByTime(offsetMs);
    runner.run(scenarios.stumble);
    vi.advanceTimersByTime(LONG_WAIT);
    expect(detected).not.toHaveBeenCalled();
  });

  it('moves in a way that is neither stillness nor another impact', () => {
    const [, ...movement] = scenarios.stumble.steps.filter(({ setOverride }) => setOverride);
    expect(movement.length).toBeGreaterThan(0);

    for (const { setOverride } of movement) {
      const value = magnitude(setOverride.value);
      expect(value).toBeLessThan(impactThresholdG);
      expect(Math.abs(value - 1)).toBeGreaterThan(immobilityToleranceG);
    }
  });

  it('starts with an impact and hands the sensor back at the end', () => {
    const { steps } = scenarios.stumble;
    expect(magnitude(steps[0].setOverride.value)).toBeGreaterThanOrEqual(impactThresholdG);
    expect(steps.at(-1).clearOverride).toBe('accelerometer');
  });

  it('is already over when the detector has gone back to idle', () => {
    vi.advanceTimersByTime(999);
    runner.run(scenarios.stumble);
    vi.advanceTimersByTime(lastAt(scenarios.stumble));
    expect(device.fall.getDetectorState()).toBe('idle');
  });
});

describe('high heart rate at rest', () => {
  it('sustains 140 BPM and a still accelerometer without any fall alert', () => {
    runner.run(scenarios.highHeartRate);
    vi.advanceTimersByTime(LONG_WAIT);

    expect(state().heartRate).toBe(140);
    expect(state().accelerometer).toEqual({ x: 0, y: 0, z: 1 });
    expect(detected).not.toHaveBeenCalled();
  });
});

describe('critical heart rate at rest', () => {
  it('sends the alert by itself, with no countdown', () => {
    runner.run(scenarios.criticalHeartRate);
    vi.advanceTimersByTime(criticalHeartRateConfig.sustainedDurationMs + TICK);

    expect(state().heartRate).toBe(170);
    expect(device.alerts.getAlerts().map(({ type }) => type)).toEqual(['high-heart-rate']);
    expect(state().deviceStatus.mode).toBe('monitoring');
    expect(device.countdown.isRunning()).toBe(false);
    expect(detected).not.toHaveBeenCalled();
  });
});

describe('battery', () => {
  it('stays at 15% when low', () => {
    runner.run(scenarios.lowBattery);
    vi.advanceTimersByTime(TICK * 100);
    expect(state().battery.level).toBe(15);
  });

  it('stays at 5% when critical', () => {
    runner.run(scenarios.criticalBattery);
    vi.advanceTimersByTime(TICK * 100);
    expect(state().battery.level).toBe(5);
  });
});

describe('GPS lost', () => {
  it('keeps the signal off and the last known position', () => {
    const { lat, lng } = state().gps;
    runner.run(scenarios.gpsLost);
    vi.advanceTimersByTime(TICK * 10);

    expect(state().gps.signal).toBe(false);
    expect(state().gps.lat).toBe(lat);
    expect(state().gps.lng).toBe(lng);
  });
});
