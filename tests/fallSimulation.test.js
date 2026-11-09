import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { createFallSimulation } from '../src/simulator/fallSimulation.js';

const LONGEST_WAIT = fallDetectionConfig.immobilityDurationMs + telemetryConfig.tickIntervalMs;

let device;
let simulation;

const mode = () => device.store.getState().deviceStatus.mode;

beforeEach(() => {
  vi.useFakeTimers();
  device = createDevice({ createAudioContext: () => null });
  simulation = createFallSimulation({ engine: device.engine });
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe('simulateFall', () => {
  it('reaches the real detector, which confirms only after the stillness', () => {
    device.start();
    const detected = vi.fn();
    device.fall.on('fall:detected', detected);

    expect(simulation.simulateFall()).toBe(true);
    expect(detected).not.toHaveBeenCalled();
    vi.advanceTimersByTime(fallDetectionConfig.immobilityDurationMs - 1);
    expect(detected).not.toHaveBeenCalled();

    vi.advanceTimersByTime(LONGEST_WAIT);
    expect(detected).toHaveBeenCalledTimes(1);
    expect(mode()).toBe('fall-countdown');
  });

  it('hands the sensor back to the generator afterwards', () => {
    device.start();
    simulation.simulateFall();
    vi.advanceTimersByTime(LONGEST_WAIT + telemetryConfig.tickIntervalMs * 5);

    // The generator always adds some noise, and the override never does.
    const readings = new Set();
    device.store.subscribe(({ accelerometer }) => readings.add(JSON.stringify(accelerometer)));
    vi.advanceTimersByTime(telemetryConfig.tickIntervalMs * 5);
    expect(readings.size).toBeGreaterThan(1);
  });

  it('does nothing before the watch is started', () => {
    const warning = vi.spyOn(console, 'warn').mockImplementation(() => {});

    expect(simulation.simulateFall()).toBe(false);
    vi.advanceTimersByTime(LONGEST_WAIT * 2);

    expect(warning).toHaveBeenCalledTimes(1);
    expect(mode()).toBe('monitoring');
  });

  it('can be used again after cancelling', () => {
    device.start();
    const detected = vi.fn();
    device.fall.on('fall:detected', detected);

    simulation.simulateFall();
    vi.advanceTimersByTime(LONGEST_WAIT);
    device.fall.cancel();
    simulation.simulateFall();
    vi.advanceTimersByTime(LONGEST_WAIT);

    expect(detected).toHaveBeenCalledTimes(2);
  });
});
