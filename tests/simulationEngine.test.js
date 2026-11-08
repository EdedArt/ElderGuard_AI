import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createSimulationEngine } from '../src/core/simulationEngine.js';
import { createTelemetryStore } from '../src/core/telemetryStore.js';

const TICK = telemetryConfig.tickIntervalMs;

function setup() {
  const store = createTelemetryStore();
  // Always the top of the range, so generated values visibly differ from the initial state.
  const engine = createSimulationEngine({ store, random: () => 0.99, now: () => 12345 });
  return { store, engine };
}

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('start and stop', () => {
  it('does not run or tick until started', () => {
    const { store, engine } = setup();
    const initial = store.getState();

    vi.advanceTimersByTime(TICK * 3);

    expect(engine.isRunning()).toBe(false);
    expect(store.getState()).toEqual(initial);
  });

  it('reports its running state', () => {
    const { engine } = setup();
    engine.start();
    expect(engine.isRunning()).toBe(true);
    engine.stop();
    expect(engine.isRunning()).toBe(false);
  });

  it('stops updating the store after stop', () => {
    const { store, engine } = setup();
    engine.start();
    vi.advanceTimersByTime(TICK);
    engine.stop();
    const stopped = store.getState();

    vi.advanceTimersByTime(TICK * 3);

    expect(store.getState()).toEqual(stopped);
  });

  it('does not double the tick rate when started twice', () => {
    const { store, engine } = setup();
    const listener = vi.fn();
    store.subscribe(listener);
    engine.start();
    engine.start();

    vi.advanceTimersByTime(TICK * 2);

    expect(listener).toHaveBeenCalledTimes(2);
    engine.stop();
    expect(engine.isRunning()).toBe(false);
    vi.advanceTimersByTime(TICK);
    expect(listener).toHaveBeenCalledTimes(2);
  });

  it('can stop when not running and start again afterwards', () => {
    const { store, engine } = setup();
    expect(() => engine.stop()).not.toThrow();
    engine.start();
    engine.stop();
    engine.start();
    const listener = vi.fn();
    store.subscribe(listener);

    vi.advanceTimersByTime(TICK);

    expect(listener).toHaveBeenCalledTimes(1);
    engine.stop();
  });
});

describe('ticks', () => {
  it('writes every sensor and the timestamp in a single store update', () => {
    const { store, engine } = setup();
    const before = store.getState();
    const listener = vi.fn();
    store.subscribe(listener);
    engine.start();

    vi.advanceTimersByTime(TICK);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener.mock.calls[0][1].sort()).toEqual([
      'accelerometer',
      'battery',
      'deviceStatus',
      'gps',
      'heartRate',
    ]);
    const after = store.getState();
    expect(after.heartRate).toBe(before.heartRate + telemetryConfig.heartRate.noise);
    expect(after.battery.level).toBeLessThan(before.battery.level);
    expect(after.deviceStatus).toEqual({ mode: 'monitoring', lastUpdate: 12345 });
    engine.stop();
  });

  it('ticks at the configured interval', () => {
    const { store, engine } = setup();
    const listener = vi.fn();
    store.subscribe(listener);
    engine.start();

    vi.advanceTimersByTime(TICK - 1);
    expect(listener).not.toHaveBeenCalled();

    vi.advanceTimersByTime(1);
    expect(listener).toHaveBeenCalledTimes(1);
    engine.stop();
  });
});

describe('overrides', () => {
  it('uses the override value instead of the generator on every tick', () => {
    const { store, engine } = setup();
    engine.start();
    engine.setOverride('heartRate', 150);

    vi.advanceTimersByTime(TICK * 3);

    expect(store.getState().heartRate).toBe(150);
    engine.stop();
  });

  it('keeps generating the other sensors', () => {
    const { store, engine } = setup();
    const before = store.getState();
    engine.start();
    engine.setOverride('heartRate', 150);

    vi.advanceTimersByTime(TICK);

    expect(store.getState().battery.level).toBeLessThan(before.battery.level);
    engine.stop();
  });

  it('applies right away, even while stopped', () => {
    const { store, engine } = setup();
    engine.setOverride('accelerometer', { x: 3, y: 3, z: 3 });
    expect(store.getState().accelerometer).toEqual({ x: 3, y: 3, z: 3 });
  });

  it('accepts a partial value and merges it with the rest of the sensor', () => {
    const { store, engine } = setup();
    const before = store.getState();
    engine.setOverride('gps', { signal: false });
    engine.start();

    vi.advanceTimersByTime(TICK);

    expect(store.getState().gps).toEqual({ ...before.gps, signal: false });
    engine.stop();
  });

  it('is not affected by later changes to the object it was given', () => {
    const { store, engine } = setup();
    const value = { x: 3, y: 3, z: 3 };
    engine.setOverride('accelerometer', value);
    value.x = 9;
    engine.start();

    vi.advanceTimersByTime(TICK);

    expect(store.getState().accelerometer.x).toBe(3);
    engine.stop();
  });

  it('resumes generation after clearOverride', () => {
    const { store, engine } = setup();
    const { restingMax } = telemetryConfig.heartRate;
    engine.setOverride('heartRate', 150);
    engine.setOverride('gps', { signal: false });
    engine.start();

    engine.clearOverride('heartRate');
    engine.clearOverride('gps');
    vi.advanceTimersByTime(TICK);

    expect(store.getState().heartRate).toBe(restingMax);
    expect(store.getState().gps.signal).toBe(true);
    engine.stop();
  });

  it('continues from an overridden battery level after clearing it', () => {
    const { store, engine } = setup();
    engine.setOverride('battery', { level: 15 });
    engine.clearOverride('battery');
    engine.start();

    vi.advanceTimersByTime(TICK);

    expect(store.getState().battery.level).toBeCloseTo(
      15 - telemetryConfig.battery.drainPerTick,
      8,
    );
    engine.stop();
  });

  it('clearAllOverrides resumes every sensor', () => {
    const { store, engine } = setup();
    const { restingMax } = telemetryConfig.heartRate;
    engine.setOverride('heartRate', 150);
    engine.setOverride('accelerometer', { x: 3, y: 3, z: 3 });
    engine.start();

    engine.clearAllOverrides();
    vi.advanceTimersByTime(TICK);

    const state = store.getState();
    expect(state.heartRate).toBe(restingMax);
    expect(state.accelerometer.x).toBeLessThan(1);
    engine.stop();
  });

  it('rejects unknown sensors', () => {
    const { engine } = setup();
    expect(() => engine.setOverride('temperature', 40)).toThrow('Unknown sensor');
    expect(() => engine.clearOverride('temperature')).toThrow('Unknown sensor');
    expect(() => engine.setOverride('constructor', 1)).toThrow('Unknown sensor');
  });
});
