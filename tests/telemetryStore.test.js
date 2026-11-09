import { describe, expect, it, vi } from 'vitest';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createTelemetryStore } from '../src/core/telemetryStore.js';

describe('createTelemetryStore', () => {
  it('starts with the documented state shape', () => {
    const { gps, battery } = telemetryConfig;
    expect(createTelemetryStore().getState()).toEqual({
      heartRate: 70,
      accelerometer: { x: 0, y: 0, z: 1 },
      gps: { lat: gps.baseLat, lng: gps.baseLng, accuracy: gps.accuracyMin, signal: true },
      battery: { level: battery.startLevel, charging: false },
      deviceStatus: { mode: 'monitoring', lastUpdate: null, healthAlert: null },
    });
  });

  it('does not share the initial accelerometer object with the config', () => {
    const store = createTelemetryStore();
    store.update({ accelerometer: { x: 5 } });
    expect(telemetryConfig.accelerometer.rest.x).toBe(0);
  });
});

describe('getState', () => {
  it('returns a copy that cannot change the store', () => {
    const store = createTelemetryStore();
    const state = store.getState();
    state.heartRate = 999;
    state.gps.signal = false;

    expect(store.getState().heartRate).toBe(70);
    expect(store.getState().gps.signal).toBe(true);
  });
});

describe('update', () => {
  it('merges nested values and keeps the rest', () => {
    const store = createTelemetryStore();
    const before = store.getState();

    store.update({ gps: { signal: false } });

    expect(store.getState().gps).toEqual({ ...before.gps, signal: false });
    expect(store.getState().heartRate).toBe(before.heartRate);
  });

  it('notifies subscribers with the new state and the changed keys', () => {
    const store = createTelemetryStore();
    const listener = vi.fn();
    store.subscribe(listener);

    store.update({ heartRate: 90, battery: { level: 50 } });

    expect(listener).toHaveBeenCalledTimes(1);
    const [state, changedKeys] = listener.mock.calls[0];
    expect(state.heartRate).toBe(90);
    expect(state.battery.level).toBe(50);
    expect(changedKeys).toEqual(['heartRate', 'battery']);
  });

  it('leaves out keys whose values did not really change', () => {
    const store = createTelemetryStore();
    const listener = vi.fn();
    store.subscribe(listener);

    store.update({ heartRate: 90, gps: { signal: true } });

    expect(listener.mock.calls[0][1]).toEqual(['heartRate']);
  });

  it('does not notify when nothing changed', () => {
    const store = createTelemetryStore();
    const listener = vi.fn();
    store.subscribe(listener);

    store.update({ heartRate: store.getState().heartRate, gps: { signal: true } });

    expect(listener).not.toHaveBeenCalled();
  });

  it('ignores unknown keys and values that would break the shape', () => {
    const store = createTelemetryStore();
    const before = store.getState();

    store.update({ unknown: 1, gps: { altitude: 10 }, battery: null, accelerometer: 3 });
    store.update(JSON.parse('{"__proto__": {"polluted": true}}'));

    expect(store.getState()).toEqual(before);
    expect({}.polluted).toBeUndefined();
  });

  it('does not keep a reference to the object it was given', () => {
    const store = createTelemetryStore();
    const accelerometer = { x: 1, y: 1, z: 1 };
    store.update({ accelerometer });
    accelerometer.x = 9;

    expect(store.getState().accelerometer.x).toBe(1);
  });

  it('gives listeners a copy that cannot change the store', () => {
    const store = createTelemetryStore();
    store.subscribe((state) => {
      state.heartRate = 999;
    });

    store.update({ heartRate: 90 });

    expect(store.getState().heartRate).toBe(90);
  });
});

describe('subscribe', () => {
  it('returns an unsubscribe function', () => {
    const store = createTelemetryStore();
    const listener = vi.fn();
    const unsubscribe = store.subscribe(listener);

    unsubscribe();
    store.update({ heartRate: 90 });

    expect(listener).not.toHaveBeenCalled();
  });
});

describe('reset', () => {
  it('restores the initial state and reports what changed', () => {
    const store = createTelemetryStore();
    const initial = store.getState();
    store.update({ heartRate: 150, gps: { signal: false } });
    const listener = vi.fn();
    store.subscribe(listener);

    store.reset();

    expect(store.getState()).toEqual(initial);
    expect(listener.mock.calls[0][1]).toEqual(['heartRate', 'gps']);
  });

  it('does not notify when the state is already initial', () => {
    const store = createTelemetryStore();
    const listener = vi.fn();
    store.subscribe(listener);

    store.reset();

    expect(listener).not.toHaveBeenCalled();
  });
});

describe('updates made from inside a listener', () => {
  it('reach every listener in order, after the current round', () => {
    const store = createTelemetryStore();
    const seen = [];
    store.subscribe((state) => {
      if (state.heartRate === 90) store.update({ heartRate: 91 });
    });
    store.subscribe((state) => seen.push(state.heartRate));

    store.update({ heartRate: 90 });

    expect(seen).toEqual([90, 91]);
  });

  it('are visible to getState right away', () => {
    const store = createTelemetryStore();
    let current;
    store.subscribe((state) => {
      if (state.heartRate === 90) {
        store.update({ heartRate: 91 });
        current = store.getState().heartRate;
      }
    });

    store.update({ heartRate: 90 });

    expect(current).toBe(91);
  });

  it('do not block later updates when a listener throws', () => {
    const store = createTelemetryStore();
    const unsubscribe = store.subscribe(() => {
      throw new Error('listener failed');
    });
    expect(() => store.update({ heartRate: 90 })).toThrow('listener failed');
    unsubscribe();

    const listener = vi.fn();
    store.subscribe(listener);
    store.update({ heartRate: 91 });
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
