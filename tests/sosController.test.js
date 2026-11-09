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

  it('emits sos:cancelled with the time, only when an SOS was active', () => {
    const { sos } = setup();
    const listener = vi.fn();
    sos.on('sos:cancelled', listener);

    sos.cancel();
    expect(listener).not.toHaveBeenCalled();

    sos.trigger({ reason: 'manual' });
    sos.cancel();
    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith({ timestamp: 12345 });
  });

  it('sets the mode to sos and emits sos:triggered with the time and location', () => {
    const { store, sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger({ reason: 'manual' });

    expect(store.getState().deviceStatus.mode).toBe('sos');
    expect(sos.isActive()).toBe(true);
    expect(listener).toHaveBeenCalledWith({
      reason: 'manual',
      timestamp: 12345,
      gps: store.getState().gps,
    });
  });

  it('reports the reason it was given', () => {
    const { sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger({ reason: 'fall' });

    expect(listener.mock.calls[0][0].reason).toBe('fall');
  });

  it('emits only once while already active', () => {
    const { sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger({ reason: 'manual' });
    sos.trigger({ reason: 'manual' });

    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('returns to monitoring on cancel and can trigger again', () => {
    const { store, sos } = setup();
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    sos.trigger({ reason: 'manual' });
    sos.cancel();
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
    expect(sos.isActive()).toBe(false);

    sos.trigger({ reason: 'manual' });
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

    sos.trigger({ reason: 'manual' });

    expect(store.getState().deviceStatus).toEqual({ mode: 'sos', lastUpdate: 999 });
  });
});
