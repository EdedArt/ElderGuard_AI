// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { heartRateAnomalyConfig } from '../src/config/heartRateAnomaly.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { setLanguage } from '../src/i18n/index.js';
import { SPIKE_HOLD_MS, scenarios } from '../src/simulator/scenarios.js';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { createWatchface } from '../src/ui/watchface.js';

const { sustainedDurationMs } = heartRateAnomalyConfig;
const { countdownSeconds, immobilityDurationMs } = fallDetectionConfig;
const TICK = telemetryConfig.tickIntervalMs;
const TIME_TO_WARN = sustainedDurationMs + TICK;
const TIME_TO_DETECT_FALL = SPIKE_HOLD_MS + immobilityDurationMs + TICK;
const MOVING = { x: 0.4, y: 0.5, z: 1.4 };
const STILL = { x: 0, y: 0, z: 1 };

let device;
let face;

const banner = () => face.querySelector('.heart-rate-banner');
const announcer = () => face.querySelector('[role="status"]');
const mode = () => device.store.getState().deviceStatus.mode;

function reachWarning() {
  device.scenarioRunner.run(scenarios.highHeartRate);
  vi.advanceTimersByTime(TIME_TO_WARN);
}

beforeEach(() => {
  vi.useFakeTimers();
  localStorage.clear();
  setLanguage('es');
  device = createDevice({ createAudioContext: () => null });
  face = createWatchface({ ...device, onStart: device.start });
  document.body.replaceChildren(face);
  face.querySelector('.start-screen__button').click();
});

afterEach(() => {
  device.scenarioRunner.stop();
  device.engine.stop();
  device.fall.cancel();
  vi.useRealTimers();
});

describe('appearing', () => {
  it('is hidden during normal readings', () => {
    vi.advanceTimersByTime(TICK * 30);
    expect(banner().hidden).toBe(true);
  });

  it('appears after sustained high BPM at rest, and not before', () => {
    device.scenarioRunner.run(scenarios.highHeartRate);
    vi.advanceTimersByTime(sustainedDurationMs - 1);
    expect(banner().hidden).toBe(true);

    vi.advanceTimersByTime(TICK);
    expect(banner().hidden).toBe(false);
    expect(banner().textContent.trim()).toBe('Ritmo cardíaco alto en reposo');
  });

  it('has an icon, hidden from screen readers', () => {
    expect(banner().querySelector('svg').getAttribute('aria-hidden')).toBe('true');
  });

  it('stays while the condition lasts', () => {
    reachWarning();
    for (let tick = 0; tick < 10; tick += 1) {
      vi.advanceTimersByTime(TICK);
      expect(banner().hidden).toBe(false);
    }
  });

  it('follows the language', () => {
    reachWarning();
    setLanguage('en');
    expect(banner().textContent.trim()).toBe('High heart rate at rest');
  });
});

describe('announcing', () => {
  it('is announced politely when it appears', () => {
    expect(announcer().getAttribute('aria-live')).toBe('polite');
    reachWarning();
    expect(announcer().textContent).toBe('Ritmo cardíaco alto en reposo');
  });

  it('is announced only once while it stays', () => {
    reachWarning();
    announcer().textContent = '';
    vi.advanceTimersByTime(TICK * 10);
    expect(announcer().textContent).toBe('');
  });

  it('is announced again if it comes back', () => {
    reachWarning();
    device.engine.setOverride('heartRate', 70);
    announcer().textContent = '';

    device.engine.setOverride('heartRate', 140);
    vi.advanceTimersByTime(TIME_TO_WARN);
    expect(announcer().textContent).toBe('Ritmo cardíaco alto en reposo');
  });

  it('is announced in the language in use', () => {
    setLanguage('en');
    reachWarning();
    expect(announcer().textContent).toBe('High heart rate at rest');
  });
});

describe('what does not bring it up', () => {
  it('a brief spike', () => {
    device.engine.setOverride('accelerometer', STILL);
    device.engine.setOverride('heartRate', 140);
    vi.advanceTimersByTime(sustainedDurationMs - TICK * 2);
    device.engine.setOverride('heartRate', 70);

    vi.advanceTimersByTime(TICK * 30);
    expect(banner().hidden).toBe(true);
    expect(announcer().textContent).toBe('');
  });

  it('a high heart rate during movement', () => {
    device.engine.setOverride('accelerometer', MOVING);
    device.engine.setOverride('heartRate', 140);

    vi.advanceTimersByTime(TICK * 30);
    expect(banner().hidden).toBe(true);
  });
});

describe('disappearing', () => {
  beforeEach(reachWarning);

  it('goes when the heart rate drops', () => {
    device.engine.setOverride('heartRate', 70);
    expect(banner().hidden).toBe(true);
  });

  it('goes when movement resumes', () => {
    device.engine.setOverride('accelerometer', MOVING);
    expect(banner().hidden).toBe(true);
  });

  it('goes when the sensors return to automatic', () => {
    device.engine.clearAllOverrides();
    vi.advanceTimersByTime(TICK);
    expect(banner().hidden).toBe(true);
  });
});

describe('next to a fall countdown', () => {
  const overlay = () => face.querySelector('.fall-overlay');
  const secondsShown = () => face.querySelector('.fall-overlay__seconds').textContent;

  // The fall is what the wearer must answer, so the countdown covers the banner while it runs.
  it('the countdown runs on time with the anomaly active, and reaches the SOS', () => {
    reachWarning();
    device.scenarioRunner.run(scenarios.fall);
    vi.advanceTimersByTime(TIME_TO_DETECT_FALL);

    expect(overlay().hidden).toBe(false);
    expect(mode()).toBe('fall-countdown');
    const startedAt = Number(secondsShown());

    vi.advanceTimersByTime(TICK * 2);
    expect(Number(secondsShown())).toBe(startedAt - 2);

    vi.advanceTimersByTime(countdownSeconds * 1000);
    expect(mode()).toBe('sos');
  });

  it('the banner can appear during the countdown without closing it or taking the focus', () => {
    device.scenarioRunner.run(scenarios.fall);
    vi.advanceTimersByTime(TIME_TO_DETECT_FALL);
    expect(overlay().hidden).toBe(false);
    const focused = document.activeElement;
    const announcement = announcer().textContent;

    device.engine.setOverride('heartRate', 140);
    device.engine.setOverride('accelerometer', STILL);
    vi.advanceTimersByTime(TIME_TO_WARN - TICK);

    expect(banner().hidden).toBe(false);
    expect(overlay().hidden).toBe(false);
    expect(document.activeElement).toBe(focused);
    expect(announcer().textContent).not.toBe(announcement);
    expect(mode()).toBe('fall-countdown');
  });

  it('the banner is still there after cancelling the fall', () => {
    device.engine.setOverride('heartRate', 140);
    device.scenarioRunner.run(scenarios.fall);
    vi.advanceTimersByTime(TIME_TO_DETECT_FALL);
    vi.advanceTimersByTime(TIME_TO_WARN - TIME_TO_DETECT_FALL + SPIKE_HOLD_MS + TICK);
    expect(banner().hidden).toBe(false);

    face.querySelector('.fall-overlay__cancel').click();
    expect(overlay().hidden).toBe(true);
    expect(banner().hidden).toBe(false);
    expect(mode()).toBe('monitoring');
  });
});
