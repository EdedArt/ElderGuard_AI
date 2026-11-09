import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { createCountdown } from '../src/core/countdown.js';
import { createFallDetector, FALL_STATES } from '../src/core/fallDetector.js';
import { createFallMonitor } from '../src/core/fallMonitor.js';
import { createSosController } from '../src/core/sosController.js';
import { createTelemetryStore } from '../src/core/telemetryStore.js';

const { impactThresholdG, immobilityDurationMs } = fallDetectionConfig;

const SPIKE = { x: 0, y: 0, z: impactThresholdG + 1 };
const STILL = { x: 0, y: 0, z: 1 };

let time;
let store;
let detector;
let sos;
let countdown;
let fireCountdownTick;
let monitor;
let detected;

// One engine tick: the reading may repeat, but lastUpdate always changes.
function tick(accelerometer, elapsedMs = 1000) {
  time += elapsedMs;
  store.update({ accelerometer, deviceStatus: { lastUpdate: time } });
}

function fall() {
  tick(SPIKE);
  for (let elapsed = 0; elapsed <= immobilityDurationMs; elapsed += 1000) tick(STILL);
}

beforeEach(() => {
  time = 1000;
  store = createTelemetryStore();
  detector = createFallDetector();
  sos = createSosController({ store, now: () => time });
  // Fired by hand, so the countdown stays at its starting value unless a test moves it on.
  fireCountdownTick = null;
  countdown = createCountdown({
    timer: {
      start: (callback) => {
        fireCountdownTick = callback;
        return 1;
      },
      stop: () => {},
    },
  });
  monitor = createFallMonitor({ store, sos, countdown, detector, now: () => time });
  detected = vi.fn();
  monitor.on('fall:detected', detected);
});

describe('fall detection from telemetry', () => {
  it('feeds accelerometer updates into the detector', () => {
    store.update({ accelerometer: SPIKE });
    expect(detector.getState()).toBe(FALL_STATES.IMPACT);
  });

  it('emits fall:detected and starts the countdown mode on confirmation', () => {
    fall();

    expect(detected).toHaveBeenCalledTimes(1);
    expect(detected).toHaveBeenCalledWith({ timestamp: time, gps: store.getState().gps });
    expect(store.getState().deviceStatus.mode).toBe('fall-countdown');
  });

  it('confirms when the reading stays exactly the same while time goes by', () => {
    tick(SPIKE);
    for (let elapsed = 0; elapsed <= immobilityDurationMs; elapsed += 1000) {
      time += 1000;
      store.update({ accelerometer: STILL, deviceStatus: { lastUpdate: time } });
      expect(store.getState().accelerometer).toEqual(STILL);
    }
    expect(detected).toHaveBeenCalledTimes(1);
  });

  it('keeps the rest of the device status', () => {
    fall();
    expect(store.getState().deviceStatus.lastUpdate).toBe(time);
  });

  it('does nothing for normal telemetry', () => {
    for (let index = 0; index < 20; index += 1) tick({ x: 0.01, y: -0.01, z: 1 });
    expect(detected).not.toHaveBeenCalled();
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
  });
});

describe('while an alert is active', () => {
  it('ignores new detections during the countdown', () => {
    fall();
    fall();

    expect(detected).toHaveBeenCalledTimes(1);
    expect(detector.getState()).toBe(FALL_STATES.IDLE);
  });

  it('ignores new detections during SOS', () => {
    store.update({ deviceStatus: { mode: 'sos' } });
    fall();

    expect(detected).not.toHaveBeenCalled();
    expect(store.getState().deviceStatus.mode).toBe('sos');
  });

  it('forgets a fall in progress when an alert starts', () => {
    tick(SPIKE);
    tick(STILL);
    expect(detector.getState()).toBe(FALL_STATES.IMMOBILITY);

    store.update({ deviceStatus: { mode: 'sos' } });
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    tick(STILL, immobilityDurationMs * 2);
    store.update({ deviceStatus: { mode: 'monitoring' } });
    tick(STILL);
    expect(detected).not.toHaveBeenCalled();
  });

  it('detects again once back in monitoring', () => {
    fall();
    store.update({ deviceStatus: { mode: 'monitoring' } });
    fall();
    expect(detected).toHaveBeenCalledTimes(2);
  });
});

describe('getDetectorState', () => {
  it('follows the detector during monitoring', () => {
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IDLE);
    tick(SPIKE);
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IMPACT);
    tick(STILL);
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IMMOBILITY);
  });

  it('stays confirmed through the countdown and the SOS that follows', () => {
    fall();
    expect(monitor.getDetectorState()).toBe(FALL_STATES.CONFIRMED);

    store.update({ deviceStatus: { mode: 'sos' } });
    expect(monitor.getDetectorState()).toBe(FALL_STATES.CONFIRMED);

    store.update({ deviceStatus: { mode: 'monitoring' } });
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IDLE);
  });

  it('goes back to idle when the countdown is cancelled', () => {
    fall();
    monitor.cancel();
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IDLE);
  });

  it('resetDetector forgets a sequence in progress, but not an alert already raised', () => {
    tick(SPIKE);
    monitor.resetDetector();
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IDLE);

    fall();
    monitor.resetDetector();
    expect(monitor.getDetectorState()).toBe(FALL_STATES.CONFIRMED);
    expect(store.getState().deviceStatus.mode).toBe('fall-countdown');
  });

  it('does not report a confirmed fall for a manual SOS', () => {
    store.update({ deviceStatus: { mode: 'sos' } });
    expect(monitor.getDetectorState()).toBe(FALL_STATES.IDLE);
  });
});

describe('countdown', () => {
  it('starts when a fall is detected, from the configured value', () => {
    const ticks = [];
    countdown.onTick((remaining) => ticks.push(remaining));
    fall();

    expect(countdown.isRunning()).toBe(true);
    expect(ticks).toEqual([fallDetectionConfig.countdownSeconds]);
  });

  it('stops if something else takes the watch out of the countdown', () => {
    fall();
    store.update({ deviceStatus: { mode: 'sos' } });
    expect(countdown.isRunning()).toBe(false);
  });

  it('survives telemetry ticks while it runs', () => {
    fall();
    tick(STILL);
    tick(SPIKE);
    expect(countdown.isRunning()).toBe(true);
    expect(store.getState().deviceStatus.mode).toBe('fall-countdown');
  });

  it('cancel stops it and returns to monitoring', () => {
    fall();
    monitor.cancel();

    expect(countdown.isRunning()).toBe(false);
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
  });

  it('cancel emits fall:cancelled and resets the detector', () => {
    const cancelled = vi.fn();
    monitor.on('fall:cancelled', cancelled);
    fall();
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    tick(SPIKE);
    expect(detector.getState()).toBe(FALL_STATES.IDLE);

    monitor.cancel();

    expect(cancelled).toHaveBeenCalledTimes(1);
    expect(cancelled).toHaveBeenCalledWith({ timestamp: time });
    expect(detector.getState()).toBe(FALL_STATES.IDLE);
  });

  it('cancel only emits when a countdown was running', () => {
    const cancelled = vi.fn();
    monitor.on('fall:cancelled', cancelled);
    monitor.cancel();
    expect(cancelled).not.toHaveBeenCalled();
  });

  it('dispatches SOS with reason fall when it ends', () => {
    const triggered = vi.fn();
    sos.on('sos:triggered', triggered);
    fall();

    for (let second = 0; second < fallDetectionConfig.countdownSeconds - 1; second += 1) {
      fireCountdownTick();
    }
    expect(triggered).not.toHaveBeenCalled();

    fireCountdownTick();
    expect(triggered).toHaveBeenCalledTimes(1);
    expect(triggered.mock.calls[0][0].reason).toBe('fall');
    expect(store.getState().deviceStatus.mode).toBe('sos');
  });

  it('can detect another fall after the SOS is cancelled', () => {
    fall();
    for (let second = 0; second < fallDetectionConfig.countdownSeconds; second += 1) {
      fireCountdownTick();
    }
    sos.cancel();
    fall();

    expect(detected).toHaveBeenCalledTimes(2);
    expect(store.getState().deviceStatus.mode).toBe('fall-countdown');
  });

  it('cancel does not end an alert of another kind', () => {
    store.update({ deviceStatus: { mode: 'sos' } });
    monitor.cancel();
    expect(store.getState().deviceStatus.mode).toBe('sos');
  });
});

describe('listeners', () => {
  it('can be removed with off', () => {
    const listener = vi.fn();
    monitor.on('fall:detected', listener);
    monitor.off('fall:detected', listener);
    fall();
    expect(listener).not.toHaveBeenCalled();
  });

  it('see the mode changes in order, even subscribed after the monitor', () => {
    const modes = [];
    store.subscribe((state) => modes.push(state.deviceStatus.mode));
    fall();

    expect(modes.at(-2)).toBe('monitoring');
    expect(modes.at(-1)).toBe('fall-countdown');
  });
});
