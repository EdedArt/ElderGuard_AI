import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createDevice } from '../src/core/device.js';

let device;

beforeEach(() => {
  vi.useFakeTimers();
  device = createDevice({ createAudioContext: () => null });
});

afterEach(() => {
  device.engine.stop();
  vi.useRealTimers();
});

describe('onStart', () => {
  it('tells listeners when the watch starts, with the engine already running', () => {
    const running = [];
    device.onStart(() => running.push(device.engine.isRunning()));
    expect(running).toEqual([]);

    device.start();
    expect(running).toEqual([true]);
  });
});
