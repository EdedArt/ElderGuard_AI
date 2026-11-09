import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { contactsConfig } from '../src/config/contacts.config.js';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import {
  criticalHeartRateConfig,
  heartRateAnomalyConfig,
} from '../src/config/heartRateAnomaly.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { createDemoController } from '../src/simulator/demoController.js';

const { countdownSeconds, immobilityDurationMs } = fallDetectionConfig;
const TICK = telemetryConfig.tickIntervalMs;
const SECOND = 1000;
const TIME_TO_CONFIRM = criticalHeartRateConfig.sustainedDurationMs + TICK;
const STILL = { x: 0, y: 0, z: 1 };
const MOVING = { x: 0.4, y: 0.5, z: 1.4 };
const SPIKE = { x: 2.5, y: 1.8, z: 3.2 };

let device;
let dispatched;
let atDispatch;

const alerts = () => device.alerts.getAlerts();
const state = () => device.store.getState();

function holdRate(heartRate, accelerometer = STILL) {
  device.engine.setOverride('accelerometer', accelerometer);
  device.engine.setOverride('heartRate', heartRate);
}

function fall() {
  device.engine.setOverride('accelerometer', SPIKE);
  device.engine.setOverride('accelerometer', STILL);
  vi.advanceTimersByTime(immobilityDurationMs + TICK);
}

function expectAlertShape(alert, type) {
  expect(alert).toEqual({
    type,
    timestamp: atDispatch.timestamp,
    gps: atDispatch.state.gps,
    heartRate: atDispatch.state.heartRate,
    batteryLevel: Math.round(atDispatch.state.battery.level),
    contacts: contactsConfig,
  });
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubGlobal('fetch', vi.fn());
  vi.stubGlobal('XMLHttpRequest', vi.fn());
  device = createDevice({ createAudioContext: () => null });
  dispatched = vi.fn(() => {
    atDispatch = { timestamp: Date.now(), state: state() };
  });
  device.alerts.on('alert:dispatched', dispatched);
  device.start();
});

afterEach(() => {
  device.engine.stop();
  device.fall.cancel();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('critical threshold', () => {
  it('is above the warning threshold, with the same rest logic', () => {
    expect(criticalHeartRateConfig.bpmThreshold).toBe(160);
    expect(criticalHeartRateConfig.bpmThreshold).toBeGreaterThan(
      heartRateAnomalyConfig.bpmThreshold,
    );
    expect(criticalHeartRateConfig.stillnessToleranceG).toBe(
      heartRateAnomalyConfig.stillnessToleranceG,
    );
  });
});

describe('alerts that go out', () => {
  it('a fall SOS produces a correctly shaped alert', () => {
    fall();
    expect(alerts()).toEqual([]);

    vi.advanceTimersByTime(countdownSeconds * SECOND);
    expect(state().deviceStatus.mode).toBe('sos');
    expect(alerts()).toHaveLength(1);
    expectAlertShape(alerts()[0], 'fall');
  });

  it('a manual SOS produces a correctly shaped alert', () => {
    device.sos.trigger({ reason: 'manual' });
    expect(alerts()).toHaveLength(1);
    expectAlertShape(alerts()[0], 'manual-sos');
  });

  it('a sustained critical heart rate produces a correctly shaped alert, with no SOS', () => {
    const critical = vi.fn();
    device.alerts.on('heart-rate-critical', critical);
    holdRate(170);
    vi.advanceTimersByTime(criticalHeartRateConfig.sustainedDurationMs - 1);
    expect(alerts()).toEqual([]);

    vi.advanceTimersByTime(TICK);
    expect(critical).toHaveBeenCalledTimes(1);
    expect(alerts()).toHaveLength(1);
    expectAlertShape(alerts()[0], 'high-heart-rate');
    expect(alerts()[0].heartRate).toBe(170);
    expect(state().deviceStatus.mode).toBe('monitoring');
  });

  it('emits alert:dispatched with each alert', () => {
    device.sos.trigger({ reason: 'manual' });
    expect(dispatched).toHaveBeenCalledTimes(1);
    expect(dispatched.mock.calls[0][0]).toEqual(alerts()[0]);
  });

  it('records the battery and location of that moment, not later ones', () => {
    device.engine.setOverride('battery', { level: 42 });
    device.engine.setOverride('gps', { lat: 1, lng: 2, signal: false });
    device.sos.trigger({ reason: 'manual' });
    device.engine.setOverride('battery', { level: 5 });
    device.engine.setOverride('gps', { lat: 3, lng: 4, signal: true });

    expect(alerts()[0].batteryLevel).toBe(42);
    expect(alerts()[0].gps).toMatchObject({ lat: 1, lng: 2, signal: false });
  });

  it('keeps every alert, oldest first', () => {
    device.sos.trigger({ reason: 'manual' });
    device.sos.cancel();
    vi.advanceTimersByTime(TICK);
    device.sos.trigger({ reason: 'manual' });
    expect(alerts()).toHaveLength(2);
    expect(alerts()[1].timestamp).toBeGreaterThan(alerts()[0].timestamp);
  });

  it('hands out copies, so nobody can rewrite the history', () => {
    device.sos.trigger({ reason: 'manual' });
    alerts()[0].type = 'changed';
    alerts().pop();
    dispatched.mock.calls[0][0].heartRate = 0;

    expect(alerts()).toHaveLength(1);
    expect(alerts()[0].type).toBe('manual-sos');
    expect(alerts()[0].heartRate).not.toBe(0);
  });

  it('never uses the network: it is a mock', () => {
    device.sos.trigger({ reason: 'manual' });
    holdRate(170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM);

    expect(alerts()).toHaveLength(2);
    expect(globalThis.fetch).not.toHaveBeenCalled();
    expect(globalThis.XMLHttpRequest).not.toHaveBeenCalled();
  });
});

describe('what does not send an alert', () => {
  it('a resolved anomaly below the critical threshold', () => {
    const anomaly = vi.fn();
    const resolved = vi.fn();
    device.heartRateMonitor.on('heartRate:anomaly', anomaly);
    device.heartRateMonitor.on('heartRate:resolved', resolved);

    holdRate(140);
    vi.advanceTimersByTime(heartRateAnomalyConfig.sustainedDurationMs + TICK);
    expect(anomaly).toHaveBeenCalledTimes(1);

    device.engine.setOverride('heartRate', 70);
    expect(resolved).toHaveBeenCalledTimes(1);

    vi.advanceTimersByTime(TICK * 30);
    expect(alerts()).toEqual([]);
  });

  it('a heart rate exactly at the critical threshold', () => {
    holdRate(criticalHeartRateConfig.bpmThreshold);
    vi.advanceTimersByTime(TIME_TO_CONFIRM * 3);
    expect(alerts()).toEqual([]);
  });

  it('a brief critical spike', () => {
    holdRate(170);
    vi.advanceTimersByTime(criticalHeartRateConfig.sustainedDurationMs - TICK * 2);
    device.engine.setOverride('heartRate', 70);
    vi.advanceTimersByTime(TICK * 30);
    expect(alerts()).toEqual([]);
  });

  it('a critical heart rate while moving', () => {
    holdRate(170, MOVING);
    vi.advanceTimersByTime(TIME_TO_CONFIRM * 3);
    expect(alerts()).toEqual([]);
  });

  it('a fall cancelled in time', () => {
    fall();
    device.fall.cancel();
    vi.advanceTimersByTime(countdownSeconds * SECOND * 2);
    expect(alerts()).toEqual([]);
  });
});

describe('one alert per episode', () => {
  it('does not repeat while the critical rate lasts', () => {
    holdRate(170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM + TICK * 30);
    expect(alerts()).toHaveLength(1);
  });

  it('sends another for a new episode, and reports the end of the first', () => {
    const resolved = vi.fn();
    device.alerts.on('heart-rate-critical:resolved', resolved);
    holdRate(170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM);
    expect(device.alerts.isCriticalActive()).toBe(true);

    device.engine.setOverride('heartRate', 70);
    expect(resolved).toHaveBeenCalledTimes(1);
    expect(device.alerts.isCriticalActive()).toBe(false);

    device.engine.setOverride('heartRate', 170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM);
    expect(alerts()).toHaveLength(2);
  });
});

describe('next to the fall flow', () => {
  it('a critical alert goes out during a countdown, which carries on', () => {
    fall();
    expect(state().deviceStatus.mode).toBe('fall-countdown');

    device.engine.setOverride('heartRate', 170);
    vi.advanceTimersByTime(criticalHeartRateConfig.sustainedDurationMs);

    expect(alerts().map(({ type }) => type)).toEqual(['high-heart-rate']);
    expect(state().deviceStatus.mode).toBe('fall-countdown');
    expect(device.countdown.isRunning()).toBe(true);

    vi.advanceTimersByTime(countdownSeconds * SECOND);
    expect(alerts().map(({ type }) => type)).toEqual(['high-heart-rate', 'fall']);
  });
});

describe('reset all', () => {
  it('clears the alert history and tells the page', () => {
    const cleared = vi.fn();
    device.alerts.on('alerts:cleared', cleared);
    const controller = createDemoController({ device });
    device.sos.trigger({ reason: 'manual' });
    expect(alerts()).toHaveLength(1);

    controller.resetAll();

    expect(alerts()).toEqual([]);
    expect(cleared).toHaveBeenCalledTimes(1);
  });

  it('stops the critical count, so no alert follows it', () => {
    const controller = createDemoController({ device });
    holdRate(170);
    vi.advanceTimersByTime(TICK * 3);

    controller.resetAll();
    vi.advanceTimersByTime(TIME_TO_CONFIRM * 2);
    expect(alerts()).toEqual([]);
  });

  it('allows a new alert for a condition that started before the reset', () => {
    const controller = createDemoController({ device });
    holdRate(170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM);
    expect(device.alerts.isCriticalActive()).toBe(true);

    controller.resetAll();
    expect(device.alerts.isCriticalActive()).toBe(false);

    holdRate(170);
    vi.advanceTimersByTime(TIME_TO_CONFIRM);
    expect(alerts()).toHaveLength(1);
  });
});
