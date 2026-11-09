// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { sosConfig } from '../src/config/sos.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { setLanguage } from '../src/i18n/index.js';
import { createFallSimulation } from '../src/simulator/fallSimulation.js';
import { SPIKE_HOLD_MS } from '../src/simulator/scenarios.js';
import { createWatchface } from '../src/ui/watchface.js';

const { countdownSeconds, immobilityDurationMs } = fallDetectionConfig;
const SECOND = 1000;
const TICK = telemetryConfig.tickIntervalMs;
const TIME_TO_DETECT = SPIKE_HOLD_MS + immobilityDurationMs;

let device;
let face;
let simulation;
let beeps;
let detected;
let cancelled;
let triggered;

const query = (selector) => face.querySelector(selector);
const startButton = () => query('.start-screen__button');
const overlay = () => query('.fall-overlay');
const secondsShown = () => query('.fall-overlay__seconds').textContent;
const cancelButton = () => query('.fall-overlay__cancel');
const sosScreen = () => query('.sos-screen');
const sosCancelButton = () => query('.sos-screen__cancel');
const sosButton = () => query('.sos-button');
const background = () => query('.watchface__bottom');
const announcer = () => query('[aria-live="assertive"]');
const mode = () => device.store.getState().deviceStatus.mode;

function createFakeAudioContext() {
  return {
    state: 'running',
    currentTime: 0,
    destination: {},
    resume: () => Promise.resolve(),
    createOscillator() {
      const oscillator = {
        frequency: { value: 0 },
        connect() {},
        start: () => beeps.push(oscillator.frequency.value),
        stop() {},
      };
      return oscillator;
    },
    createGain: () => ({
      gain: { setValueAtTime() {}, linearRampToValueAtTime() {} },
      connect() {},
    }),
  };
}

function start() {
  startButton().click();
}

// The impact lasts a moment; the detector then needs the stillness to last.
function detectFall() {
  simulation.simulateFall();
  vi.advanceTimersByTime(TIME_TO_DETECT);
}

function reachSos() {
  detectFall();
  vi.advanceTimersByTime(countdownSeconds * SECOND);
}

function press(key, target, init = {}) {
  const event = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, key, ...init });
  target.dispatchEvent(event);
  return event;
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 10, 8, 14, 5, 30));
  setLanguage('es');
  localStorage.clear();

  beeps = [];
  device = createDevice({ createAudioContext: createFakeAudioContext });
  simulation = createFallSimulation({ engine: device.engine });
  face = createWatchface({ ...device, onStart: device.start });
  document.body.replaceChildren(face);

  detected = vi.fn();
  cancelled = vi.fn();
  triggered = vi.fn();
  device.fall.on('fall:detected', detected);
  device.fall.on('fall:cancelled', cancelled);
  device.sos.on('sos:triggered', triggered);
});

afterEach(() => {
  device.engine.stop();
  vi.useRealTimers();
});

describe('start screen', () => {
  it('holds back telemetry and the watch until tapped', () => {
    const before = device.store.getState();
    vi.advanceTimersByTime(TICK * 5);

    expect(device.engine.isRunning()).toBe(false);
    expect(device.audio.isUnlocked()).toBe(false);
    expect(device.store.getState()).toEqual(before);
    expect(background().hasAttribute('inert')).toBe(true);
  });

  it('unlocks the audio and starts telemetry when tapped', () => {
    const listener = vi.fn();
    device.store.subscribe(listener);
    start();

    expect(device.engine.isRunning()).toBe(true);
    expect(device.audio.isUnlocked()).toBe(true);
    expect(query('.start-screen').hidden).toBe(true);

    vi.advanceTimersByTime(TICK);
    expect(listener).toHaveBeenCalled();
  });

  it('cannot detect a fall before starting', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    detectFall();
    vi.restoreAllMocks();

    expect(detected).not.toHaveBeenCalled();
    expect(overlay().hidden).toBe(true);
  });
});

describe('with the watch started', () => {
  beforeEach(start);

  describe('fall countdown overlay', () => {
    it('is hidden during normal monitoring', () => {
      vi.advanceTimersByTime(TICK * 30);
      expect(overlay().hidden).toBe(true);
      expect(mode()).toBe('monitoring');
    });

    it('appears on detection with the question, the seconds and the button', () => {
      vi.advanceTimersByTime(TICK);
      simulation.simulateFall();
      vi.advanceTimersByTime(TIME_TO_DETECT - 1);
      expect(overlay().hidden).toBe(true);

      vi.advanceTimersByTime(TICK);
      expect(detected).toHaveBeenCalledTimes(1);
      expect(overlay().hidden).toBe(false);
      expect(query('.fall-overlay__title').textContent).toBe('¿Te caíste?');
      expect(secondsShown()).toBe(String(countdownSeconds));
      expect(cancelButton().textContent).toBe('ESTOY BIEN');
      expect(mode()).toBe('fall-countdown');
    });

    it('counts down once per second', () => {
      detectFall();
      for (let remaining = countdownSeconds - 1; remaining > 0; remaining -= 1) {
        vi.advanceTimersByTime(SECOND);
        expect(secondsShown()).toBe(String(remaining));
      }
    });

    it('drains its ring over the whole countdown', () => {
      detectFall();
      expect(query('.fall-overlay__ring-progress')).not.toBeNull();
      expect(overlay().style.getPropertyValue('--fall-countdown-duration')).toBe(
        `${countdownSeconds}s`,
      );
    });

    it('turns urgent in the last seconds only', () => {
      detectFall();
      const isUrgent = () => overlay().classList.contains('fall-overlay--urgent');
      expect(isUrgent()).toBe(false);

      vi.advanceTimersByTime((countdownSeconds - 4) * SECOND);
      expect(secondsShown()).toBe('4');
      expect(isUrgent()).toBe(false);

      vi.advanceTimersByTime(SECOND);
      expect(secondsShown()).toBe('3');
      expect(isUrgent()).toBe(true);
    });

    it('stays open and keeps the watchface disabled across telemetry ticks', () => {
      detectFall();
      for (let second = 0; second < 3; second += 1) {
        vi.advanceTimersByTime(TICK);
        expect(overlay().hidden).toBe(false);
        expect(background().hasAttribute('inert')).toBe(true);
        expect(document.activeElement).toBe(cancelButton());
      }
    });

    it('does not start a second countdown while one is active', () => {
      detectFall();
      vi.advanceTimersByTime(2 * SECOND);
      const shown = secondsShown();

      simulation.simulateFall();
      vi.advanceTimersByTime(immobilityDurationMs - 2 * SECOND);

      expect(detected).toHaveBeenCalledTimes(1);
      expect(Number(secondsShown())).toBe(
        Number(shown) - (immobilityDurationMs - 2 * SECOND) / SECOND,
      );
      expect(mode()).toBe('fall-countdown');
    });

    it('follows the language', () => {
      detectFall();
      setLanguage('en');
      expect(query('.fall-overlay__title').textContent).toBe('Did you fall?');
      expect(cancelButton().textContent).toBe("I'M OK");
    });
  });

  describe('beep and vibration', () => {
    afterEach(() => {
      delete navigator.vibrate;
    });

    it('beeps every second, and more often at a higher pitch in the last seconds', () => {
      detectFall();
      expect(beeps).toHaveLength(1);

      vi.advanceTimersByTime((countdownSeconds - 4) * SECOND);
      expect(beeps).toHaveLength(countdownSeconds - 3);
      const normalPitch = beeps.at(-1);

      vi.advanceTimersByTime(SECOND);
      expect(beeps.length).toBeGreaterThan(countdownSeconds - 2);
      expect(beeps.at(-1)).toBeGreaterThan(normalPitch);
    });

    it('stops beeping after a cancel', () => {
      detectFall();
      cancelButton().click();
      const count = beeps.length;
      vi.advanceTimersByTime(countdownSeconds * SECOND);
      expect(beeps).toHaveLength(count);
    });

    it('vibrates each second, if available', () => {
      const vibrate = vi.fn();
      Object.defineProperty(navigator, 'vibrate', { value: vibrate, configurable: true });

      detectFall();
      expect(vibrate).toHaveBeenCalledTimes(1);
      vi.advanceTimersByTime(2 * SECOND);
      expect(vibrate).toHaveBeenCalledTimes(3);
    });

    it('runs the whole countdown when audio is unavailable', () => {
      const silent = createDevice({
        createAudioContext: () => {
          throw new Error('no audio');
        },
      });
      const silentFace = createWatchface({ ...silent, onStart: silent.start });
      silentFace.querySelector('.start-screen__button').click();

      createFallSimulation({ engine: silent.engine }).simulateFall();
      vi.advanceTimersByTime(TIME_TO_DETECT + countdownSeconds * SECOND);

      expect(silent.store.getState().deviceStatus.mode).toBe('sos');
      silent.engine.stop();
    });
  });

  describe('"Estoy bien"', () => {
    beforeEach(detectFall);

    it('cancels, emits fall:cancelled and restores monitoring', () => {
      vi.advanceTimersByTime(3 * SECOND);
      cancelButton().click();

      expect(cancelled).toHaveBeenCalledTimes(1);
      expect(overlay().hidden).toBe(true);
      expect(mode()).toBe('monitoring');
      expect(background().hasAttribute('inert')).toBe(false);
      expect(document.activeElement).toBe(sosButton());
    });

    it('never dispatches SOS after cancelling', () => {
      cancelButton().click();
      vi.advanceTimersByTime((countdownSeconds + 1) * SECOND);

      expect(triggered).not.toHaveBeenCalled();
      expect(mode()).toBe('monitoring');
    });

    it('does not detect the same fall again', () => {
      cancelButton().click();
      vi.advanceTimersByTime(immobilityDurationMs * 3);
      expect(detected).toHaveBeenCalledTimes(1);
    });

    it('allows a new detection, with a full countdown', () => {
      vi.advanceTimersByTime(4 * SECOND);
      cancelButton().click();
      detectFall();

      expect(detected).toHaveBeenCalledTimes(2);
      expect(secondsShown()).toBe(String(countdownSeconds));
      expect(overlay().classList.contains('fall-overlay--urgent')).toBe(false);
    });
  });

  describe('reaching zero', () => {
    it('opens the SOS screen and emits sos:triggered with reason fall', () => {
      detectFall();
      vi.advanceTimersByTime(countdownSeconds * SECOND - 1);
      expect(triggered).not.toHaveBeenCalled();
      expect(sosScreen().hidden).toBe(true);

      vi.advanceTimersByTime(1);
      expect(triggered).toHaveBeenCalledTimes(1);
      expect(triggered.mock.calls[0][0].reason).toBe('fall');
      expect(overlay().hidden).toBe(true);
      expect(sosScreen().hidden).toBe(false);
      expect(mode()).toBe('sos');
    });

    it('hands the focus and the disabled background over to the SOS screen', () => {
      reachSos();
      expect(document.activeElement).toBe(sosCancelButton());
      expect(background().hasAttribute('inert')).toBe(true);

      vi.advanceTimersByTime(TICK * 2);
      expect(document.activeElement).toBe(sosCancelButton());
      expect(background().hasAttribute('inert')).toBe(true);
    });

    it('ignores new falls during the SOS', () => {
      reachSos();
      simulation.simulateFall();
      vi.advanceTimersByTime(immobilityDurationMs * 2);

      expect(detected).toHaveBeenCalledTimes(1);
      expect(mode()).toBe('sos');
    });

    it('cancelling the SOS restores monitoring and detection', () => {
      reachSos();
      sosCancelButton().click();

      expect(mode()).toBe('monitoring');
      expect(document.activeElement).toBe(sosButton());
      expect(background().hasAttribute('inert')).toBe(false);

      detectFall();
      expect(detected).toHaveBeenCalledTimes(2);
      expect(overlay().hidden).toBe(false);
    });
  });

  describe('other ways into the alerts', () => {
    it('reports reason manual for the long press, with no countdown', () => {
      sosButton().dispatchEvent(new MouseEvent('pointerdown', { bubbles: true, button: 0 }));
      vi.advanceTimersByTime(sosConfig.holdDurationMs);

      expect(triggered.mock.calls[0][0].reason).toBe('manual');
      expect(overlay().hidden).toBe(true);
    });

    it('a fall interrupts a long press in progress, and the countdown stays in charge', () => {
      const headStart = 500;
      sosButton().focus();
      simulation.simulateFall();
      vi.advanceTimersByTime(TIME_TO_DETECT - headStart);
      sosButton().dispatchEvent(new MouseEvent('pointerdown', { bubbles: true, button: 0 }));
      vi.advanceTimersByTime(headStart);
      expect(overlay().hidden).toBe(false);

      vi.advanceTimersByTime(sosConfig.holdDurationMs);
      expect(triggered).not.toHaveBeenCalled();
      expect(mode()).toBe('fall-countdown');
      expect(sosButton().classList.contains('sos-button--holding')).toBe(false);
    });

    it('stops the countdown if SOS starts while it runs', () => {
      detectFall();
      device.sos.trigger({ reason: 'manual' });
      vi.advanceTimersByTime(countdownSeconds * SECOND);

      expect(triggered).toHaveBeenCalledTimes(1);
      expect(triggered.mock.calls[0][0].reason).toBe('manual');
      expect(overlay().hidden).toBe(true);
    });

    it('a fall closes the screen reader confirmation and takes the focus', () => {
      query('.sos-alternative').click();
      detectFall();

      expect(query('.sos-confirm').hidden).toBe(true);
      expect(document.activeElement).toBe(cancelButton());
      expect(background().hasAttribute('inert')).toBe(true);
    });
  });

  describe('accessibility', () => {
    it('is a modal alert with its question as the name', () => {
      detectFall();
      expect(overlay().getAttribute('role')).toBe('alertdialog');
      expect(overlay().getAttribute('aria-modal')).toBe('true');
      expect(document.getElementById(overlay().getAttribute('aria-labelledby')).textContent).toBe(
        '¿Te caíste?',
      );
    });

    it('moves the focus to the button when it opens', () => {
      sosButton().focus();
      detectFall();
      expect(document.activeElement).toBe(cancelButton());
    });

    it.each([
      ['Enter', 'Enter'],
      ['Space', ' '],
    ])('%s on the focused button cancels', (_name, key) => {
      detectFall();
      expect(press(key, cancelButton()).defaultPrevented).toBe(true);

      expect(cancelled).toHaveBeenCalledTimes(1);
      expect(mode()).toBe('monitoring');
    });

    it.each([
      ['Enter', 'Enter'],
      ['Space', ' '],
    ])('%s still held from before the overlay does not cancel', (_name, key) => {
      detectFall();
      expect(press(key, cancelButton(), { repeat: true }).defaultPrevented).toBe(true);

      expect(cancelled).not.toHaveBeenCalled();
      expect(overlay().hidden).toBe(false);
    });

    it('other keys do nothing', () => {
      detectFall();
      expect(press('a', cancelButton()).defaultPrevented).toBe(false);
      expect(cancelled).not.toHaveBeenCalled();
    });

    it('announces once at the start, and then only in the last 3 seconds', () => {
      expect(announcer().textContent).toBe('');

      // Every write to the region counts, even one repeating the same text.
      const writes = new MutationObserver(() => {});
      writes.observe(announcer(), { childList: true, characterData: true, subtree: true });

      detectFall();
      const startMessage = announcer().textContent;
      expect(startMessage).toContain('¿Te caíste?');
      expect(startMessage).toContain(String(countdownSeconds));
      expect(announcer().getAttribute('aria-atomic')).toBe('true');
      expect(writes.takeRecords()).toHaveLength(1);

      vi.advanceTimersByTime((countdownSeconds - 1 - fallDetectionConfig.urgentSeconds) * SECOND);
      expect(writes.takeRecords()).toHaveLength(0);
      expect(announcer().textContent).toBe(startMessage);

      for (const remaining of ['3', '2', '1']) {
        vi.advanceTimersByTime(SECOND);
        expect(writes.takeRecords()).toHaveLength(1);
        expect(announcer().textContent).toBe(remaining);
      }
      writes.disconnect();
    });

    it('never exposes the changing number to screen readers', () => {
      detectFall();
      expect(query('.fall-overlay__seconds').getAttribute('aria-hidden')).toBe('true');
    });

    it('announces in the current language', () => {
      setLanguage('en');
      detectFall();
      expect(announcer().textContent).toContain('Did you fall?');
    });

    it('clears the announcement when the alert ends', () => {
      detectFall();
      cancelButton().click();
      expect(announcer().textContent).toBe('');
    });

    it('keeps the live region available while the overlay is hidden', () => {
      expect(overlay().hidden).toBe(true);
      expect(overlay().contains(announcer())).toBe(false);
    });
  });
});
