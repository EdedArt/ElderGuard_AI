import { describe, expect, it, vi } from 'vitest';
import { createSosController } from '../src/core/sosController.js';
import { createTelemetryStore } from '../src/core/telemetryStore.js';

function setup() {
  const store = createTelemetryStore();
  const sos = createSosController({ store, now: () => 12345 });
  return { store, sos };
}

describe('createSosController', () => {
  it('starts inactive', () => {
    expect(setup().sos.isActive()).toBe(false);
  });

  it('sets the mode to sos and emits sos:triggered with the time and location', () => {
    const { store, sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger();

    expect(store.getState().deviceStatus.mode).toBe('sos');
    expect(sos.isActive()).toBe(true);
    expect(listener).toHaveBeenCalledWith({ timestamp: 12345, gps: store.getState().gps });
  });

  it('emits only once while already active', () => {
    const { sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger();
    sos.trigger();

    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('returns to monitoring on cancel and can trigger again', () => {
    const { store, sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger();
    sos.cancel();
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
    expect(sos.isActive()).toBe(false);

    sos.trigger();
    expect(listener).toHaveBeenCalledTimes(2);
  });

  it('does not touch the mode when cancelling while inactive', () => {
    const { store, sos } = setup();
    const listener = vi.fn();
    store.subscribe(listener);

    sos.cancel();

    expect(listener).not.toHaveBeenCalled();
  });

  it('keeps the other device status fields', () => {
    const { store, sos } = setup();
    store.update({ deviceStatus: { lastUpdate: 999 } });

    sos.trigger();

    expect(store.getState().deviceStatus).toEqual({ mode: 'sos', lastUpdate: 999 });
  });
});
