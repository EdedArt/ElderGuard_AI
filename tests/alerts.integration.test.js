import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { contactsConfig } from '../src/config/contacts.config.js';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { criticalHeartRateConfig } from '../src/config/heartRateAnomaly.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { SPIKE_HOLD_MS, scenarios } from '../src/simulator/scenarios.js';

const { countdownSeconds, immobilityDurationMs } = fallDetectionConfig;
const TICK = telemetryConfig.tickIntervalMs;
const SECOND = 1000;
const LONG_WAIT = 60000;

let device;
let runner;
let countdownStarted;

const alerts = () => device.alerts.getAlerts();
const mode = () => device.store.getState().deviceStatus.mode;

function expectOneAlert(type) {
  expect(alerts()).toHaveLength(1);
  const [alert] = alerts();
  expect(alert.type).toBe(type);
  expect(alert.contacts).toEqual(contactsConfig);
  expect(alert.gps).toEqual(expect.objectContaining({ lat: expect.any(Number) }));
  expect(alert.heartRate).toEqual(expect.any(Number));
  expect(alert.batteryLevel).toEqual(expect.any(Number));
  expect(alert.timestamp).toEqual(expect.any(Number));
}

beforeEach(() => {
  vi.useFakeTimers();
  device = createDevice({ createAudioContext: () => null });
  runner = device.scenarioRunner;
  countdownStarted = vi.fn();
  device.fall.on('fall:detected', countdownStarted);
  device.start();
  vi.advanceTimersByTime(TICK * 3);
});

afterEach(() => {
  runner.stop();
  device.engine.stop();
  device.fall.cancel();
  vi.useRealTimers();
});

describe('alert types, from sensors to the record', () => {
  it('fall: goes through the detector and the countdown before the SOS alert is recorded', () => {
    runner.run(scenarios.fall);
    vi.advanceTimersByTime(SPIKE_HOLD_MS + immobilityDurationMs + TICK);
    expect(mode()).toBe('fall-countdown');
    expect(countdownStarted).toHaveBeenCalledTimes(1);
    expect(alerts()).toEqual([]);

    vi.advanceTimersByTime(countdownSeconds * SECOND);
    expect(mode()).toBe('sos');
    expectOneAlert('fall');
  });

  it('manual SOS: records the alert at once, with no fall involved', () => {
    device.sos.trigger({ reason: 'manual' });

    expect(mode()).toBe('sos');
    expect(countdownStarted).not.toHaveBeenCalled();
    expectOneAlert('manual-sos');
  });

  it('critical heart rate: records the alert with no countdown, and stays monitoring', () => {
    runner.run(scenarios.criticalHeartRate);
    vi.advanceTimersByTime(criticalHeartRateConfig.sustainedDurationMs + TICK);

    expectOneAlert('high-heart-rate');
    expect(alerts()[0].heartRate).toBe(170);
    expect(countdownStarted).not.toHaveBeenCalled();
    expect(device.countdown.isRunning()).toBe(false);
    expect(mode()).toBe('monitoring');
  });
});

describe('what sends no alert', () => {
  it('stumble', () => {
    runner.run(scenarios.stumble);
    vi.advanceTimersByTime(LONG_WAIT);

    expect(alerts()).toEqual([]);
    expect(countdownStarted).not.toHaveBeenCalled();
    expect(mode()).toBe('monitoring');
  });

  it('a brief spike of the heart rate, however high', () => {
    const anomaly = vi.fn();
    device.heartRateMonitor.on('heartRate:anomaly', anomaly);

    runner.run({
      id: 'briefSpike',
      steps: [
        { atMs: 0, setOverride: { sensor: 'heartRate', value: 175 } },
        { atMs: 0, setOverride: { sensor: 'accelerometer', value: { x: 0, y: 0, z: 1 } } },
        {
          atMs: criticalHeartRateConfig.sustainedDurationMs - TICK * 2,
          clearOverride: 'heartRate',
        },
        {
          atMs: criticalHeartRateConfig.sustainedDurationMs - TICK * 2,
          clearOverride: 'accelerometer',
        },
      ],
    });
    vi.advanceTimersByTime(LONG_WAIT);

    expect(alerts()).toEqual([]);
    expect(anomaly).not.toHaveBeenCalled();
    expect(device.store.getState().deviceStatus.healthAlert).toBeNull();
  });
});

describe('a sequence of them', () => {
  it('records each alert in order, and none for what should send nothing', () => {
    runner.run(scenarios.stumble);
    vi.advanceTimersByTime(LONG_WAIT);

    runner.run(scenarios.fall);
    vi.advanceTimersByTime(LONG_WAIT);
    device.sos.cancel();

    device.sos.trigger({ reason: 'manual' });
    device.sos.cancel();

    runner.run(scenarios.criticalHeartRate);
    vi.advanceTimersByTime(LONG_WAIT);

    expect(alerts().map(({ type }) => type)).toEqual(['fall', 'manual-sos', 'high-heart-rate']);
    expect(mode()).toBe('monitoring');
  });
});
