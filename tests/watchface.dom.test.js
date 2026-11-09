// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { sosConfig } from '../src/config/sos.config.js';
import { createDevice } from '../src/core/device.js';
import { setLanguage } from '../src/i18n/index.js';
import { createWatchface } from '../src/ui/watchface.js';

const HOLD = sosConfig.holdDurationMs;

let device;
let store;
let sos;
let face;
const onStart = vi.fn();

const query = (selector) => face.querySelector(selector);
const sosButton = () => query('.sos-button');
const overlay = () => query('.sos-screen');
const cancelButton = () => query('.sos-screen__cancel');

function pointer(type, target = sosButton(), init = {}) {
  target.dispatchEvent(new MouseEvent(type, { bubbles: true, button: 0, ...init }));
}

function keyboard(type, key, target = sosButton(), init = {}) {
  const event = new KeyboardEvent(type, { bubbles: true, cancelable: true, key, ...init });
  target.dispatchEvent(event);
  return event;
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 10, 8, 14, 5, 30));
  setLanguage('es');
  localStorage.clear();

  device = createDevice();
  ({ store, sos } = device);
  face = createWatchface({ ...device, onStart });
  document.body.replaceChildren(face);
  query('.start-screen__button').click();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('start screen', () => {
  const startScreen = () => query('.start-screen');
  const startButton = () => query('.start-screen__button');

  beforeEach(() => {
    onStart.mockClear();
    face = createWatchface({ ...device, onStart });
    document.body.replaceChildren(face);
  });

  it('covers the watch and disables what is behind it until tapped', () => {
    expect(startScreen().hidden).toBe(false);
    expect(startButton().textContent).toBe('Toca para iniciar');
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);
    expect(onStart).not.toHaveBeenCalled();
  });

  it('starts once tapped, and hands the watch and the focus over', () => {
    startButton().click();

    expect(onStart).toHaveBeenCalledTimes(1);
    expect(startScreen().hidden).toBe(true);
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(false);
    expect(document.activeElement).toBe(sosButton());
  });

  it('stays until tapped, even if the language changes', () => {
    setLanguage('en');
    expect(startButton().textContent).toBe('Tap to start');
    expect(startScreen().hidden).toBe(false);
  });
});

describe('layout', () => {
  it('has the three zones with their content', () => {
    expect(query('.watchface__status .battery-indicator')).not.toBeNull();
    expect(query('.watchface__status .gps-indicator')).not.toBeNull();
    expect(query('.watchface__center .watch-clock')).not.toBeNull();
    expect(query('.watchface__center .heart-rate')).not.toBeNull();
    expect(query('.watchface__bottom .sos-button')).not.toBeNull();
  });
});

describe('clock', () => {
  it('renders the 12-hour time, the period and the short date', () => {
    expect(query('.watch-clock__time').textContent).toBe('2:05');
    expect(query('.watch-clock__period').textContent).toBe('p. m.');
    expect(query('.watch-clock__date').textContent).toContain('nov');
  });

  it('keeps up with the real time', () => {
    vi.advanceTimersByTime(30000);
    expect(query('.watch-clock__time').textContent).toBe('2:06');
  });

  it('uses the period label of the current language', () => {
    setLanguage('en');
    expect(query('.watch-clock__period').textContent).toBe('PM');
  });
});

describe('heart rate', () => {
  it('shows the store value and times the pulse to it', () => {
    store.update({ heartRate: 120 });
    const root = query('.heart-rate');

    expect(query('.heart-rate__value').textContent).toBe('120');
    expect(root.getAttribute('aria-label')).toBe('120 latidos por minuto');
    expect(root.style.getPropertyValue('--heartbeat-interval')).toBe('500ms');
  });
});

describe('battery', () => {
  const root = () => query('.battery-indicator');

  it.each([
    [100, 'normal', '100 %'],
    [21, 'normal', '21 %'],
    [20, 'low', '20 %'],
    [11, 'low', '11 %'],
    [10, 'critical', '10 %'],
    [0, 'critical', '0 %'],
  ])('at %i%% is %s and shows %s', (level, state, text) => {
    store.update({ battery: { level } });
    expect(root().dataset.state).toBe(state);
    expect(query('.battery-indicator__value').textContent).toBe(text);
    expect(root().getAttribute('aria-label')).toContain(String(level));
  });

  it('fills its icon in proportion to the level', () => {
    store.update({ battery: { level: 50 } });
    expect(query('.battery-indicator__fill').getAttribute('width')).toBe('10');
  });
});

describe('GPS', () => {
  const root = () => query('.gps-indicator');
  const label = () => query('.gps-indicator__label').textContent;

  it('shows GPS with signal', () => {
    expect(root().dataset.state).toBe('ok');
    expect(label()).toBe('GPS');
  });

  it('shows the lost label in Spanish and English', () => {
    store.update({ gps: { signal: false } });
    expect(root().dataset.state).toBe('lost');
    expect(label()).toBe('Sin GPS');

    setLanguage('en');
    expect(label()).toBe('No GPS');
    expect(root().getAttribute('aria-label')).toBe('No GPS signal');
  });
});

describe('SOS long press with a pointer', () => {
  it('activates only after the full hold', () => {
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD - 1);
    expect(overlay().hidden).toBe(true);
    expect(store.getState().deviceStatus.mode).toBe('monitoring');

    vi.advanceTimersByTime(1);
    expect(overlay().hidden).toBe(false);
    expect(store.getState().deviceStatus.mode).toBe('sos');
  });

  it('shows the progress ring while holding', () => {
    pointer('pointerdown');
    expect(sosButton().classList.contains('sos-button--holding')).toBe(true);
    pointer('pointerup');
    expect(sosButton().classList.contains('sos-button--holding')).toBe(false);
  });

  it.each(['pointerup', 'pointerleave', 'pointercancel'])('%s cancels the hold', (type) => {
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD - 1);
    pointer(type);
    vi.advanceTimersByTime(HOLD);

    expect(overlay().hidden).toBe(true);
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
  });

  it('needs a new full hold after an early release', () => {
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD - 1);
    pointer('pointerup');
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD - 1);
    expect(overlay().hidden).toBe(true);

    vi.advanceTimersByTime(1);
    expect(overlay().hidden).toBe(false);
  });

  it('ignores a plain click and other mouse buttons', () => {
    sosButton().click();
    pointer('pointerdown', sosButton(), { button: 2 });
    vi.advanceTimersByTime(HOLD);
    expect(overlay().hidden).toBe(true);
  });

  it('emits sos:triggered once', () => {
    const listener = vi.fn();
    sos.on('sos:triggered', listener);

    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener.mock.calls[0][0].reason).toBe('manual');
  });
});

describe('hold hint', () => {
  const hint = () => query('.hold-hint');
  const HINT_DURATION = sosConfig.holdHintDurationMs;

  it('starts hidden', () => {
    expect(hint().hidden).toBe(true);
  });

  it.each(['pointerup', 'pointerleave'])('shows for 2 seconds after an early %s', (type) => {
    pointer('pointerdown');
    vi.advanceTimersByTime(100);
    pointer(type);

    expect(hint().hidden).toBe(false);
    expect(hint().textContent).toBe('Mantén presionado');

    vi.advanceTimersByTime(HINT_DURATION - 1);
    expect(hint().hidden).toBe(false);
    vi.advanceTimersByTime(1);
    expect(hint().hidden).toBe(true);
  });

  it('shows after an early key release', () => {
    keyboard('keydown', 'Enter');
    keyboard('keyup', 'Enter');
    expect(hint().hidden).toBe(false);
  });

  it('is announced to screen readers', () => {
    pointer('pointerdown');
    pointer('pointerup');
    expect(query('[aria-live="polite"]').textContent).toBe('Mantén presionado');
  });

  it('uses the current language', () => {
    pointer('pointerdown');
    pointer('pointerup');
    setLanguage('en');
    expect(hint().textContent).toBe('Hold to call for help');
  });

  it('does not show after a completed hold or on release afterwards', () => {
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD);
    pointer('pointerup');
    pointer('pointerleave');
    expect(hint().hidden).toBe(true);
  });

  it('does not show without a press, or when the system interrupts the hold', () => {
    pointer('pointerup');
    pointer('pointerleave');
    pointer('pointerdown');
    pointer('pointercancel');
    expect(hint().hidden).toBe(true);
  });

  it('hides as soon as a new hold starts', () => {
    pointer('pointerdown');
    pointer('pointerup');
    pointer('pointerdown');
    expect(hint().hidden).toBe(true);
  });

  it('stays the full time after a second short press', () => {
    pointer('pointerdown');
    pointer('pointerup');
    vi.advanceTimersByTime(HINT_DURATION - 1);
    pointer('pointerdown');
    pointer('pointerup');
    vi.advanceTimersByTime(HINT_DURATION - 1);
    expect(hint().hidden).toBe(false);
  });
});

describe('SOS long press with a keyboard', () => {
  describe.each([
    ['Enter', 'Enter'],
    ['Space', ' '],
  ])('%s', (_name, key) => {
    it('activates after the full hold, ignoring key repeat', () => {
      expect(keyboard('keydown', key).defaultPrevented).toBe(true);
      vi.advanceTimersByTime(HOLD - 500);
      keyboard('keydown', key, sosButton(), { repeat: true });
      vi.advanceTimersByTime(499);
      expect(overlay().hidden).toBe(true);

      vi.advanceTimersByTime(1);
      expect(overlay().hidden).toBe(false);
    });

    it('cancels when released early', () => {
      keyboard('keydown', key);
      vi.advanceTimersByTime(HOLD - 1);
      keyboard('keyup', key);
      vi.advanceTimersByTime(HOLD);
      expect(overlay().hidden).toBe(true);
    });

    it('cannot press Cancel with the key still held from the activation', () => {
      keyboard('keydown', key);
      vi.advanceTimersByTime(HOLD);
      expect(document.activeElement).toBe(cancelButton());

      expect(keyboard('keydown', key, cancelButton(), { repeat: true }).defaultPrevented).toBe(
        true,
      );
      expect(keyboard('keyup', key, cancelButton()).defaultPrevented).toBe(true);
    });

    it('lets a new press reach Cancel after the key is released', () => {
      keyboard('keydown', key);
      vi.advanceTimersByTime(HOLD);
      keyboard('keyup', key, cancelButton());

      expect(keyboard('keydown', key, cancelButton()).defaultPrevented).toBe(false);
      expect(keyboard('keyup', key, cancelButton()).defaultPrevented).toBe(false);
    });
  });

  it('ignores other keys', () => {
    expect(keyboard('keydown', 'a').defaultPrevented).toBe(false);
    vi.advanceTimersByTime(HOLD);
    expect(overlay().hidden).toBe(true);
  });

  it('cancels the hold when focus leaves the button', () => {
    sosButton().focus();
    keyboard('keydown', 'Enter');
    sosButton().blur();
    vi.advanceTimersByTime(HOLD);
    expect(overlay().hidden).toBe(true);
  });
});

describe('screen reader alternative to the long press', () => {
  const alternative = () => query('.sos-alternative');
  const confirm = () => query('.sos-confirm');
  const yes = () => query('.sos-confirm__yes');
  const no = () => query('.sos-confirm__no');

  it('is a real focusable button with its own label', () => {
    expect(alternative().tagName).toBe('BUTTON');
    expect(alternative().textContent).toBe('Pedir ayuda');
    alternative().focus();
    expect(document.activeElement).toBe(alternative());
  });

  it('opens a modal confirmation with focus on the answer, without triggering SOS', () => {
    alternative().click();

    expect(confirm().hidden).toBe(false);
    expect(confirm().getAttribute('role')).toBe('alertdialog');
    expect(document.getElementById(confirm().getAttribute('aria-labelledby')).textContent).toBe(
      '¿Pedir ayuda?',
    );
    expect(yes().textContent).toBe('Sí, pedir ayuda');
    expect(no().textContent).toBe('No');
    expect(document.activeElement).toBe(yes());
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
  });

  it('runs the same SOS flow on confirmation', () => {
    const listener = vi.fn();
    sos.on('sos:triggered', listener);
    alternative().click();
    yes().click();

    expect(confirm().hidden).toBe(true);
    expect(overlay().hidden).toBe(false);
    expect(store.getState().deviceStatus.mode).toBe('sos');
    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener.mock.calls[0][0].reason).toBe('manual');
    expect(document.activeElement).toBe(cancelButton());
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);
  });

  it('No closes it, restores the watchface and returns focus', () => {
    alternative().click();
    no().click();

    expect(confirm().hidden).toBe(true);
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(false);
    expect(document.activeElement).toBe(alternative());
    expect(store.getState().deviceStatus.mode).toBe('monitoring');
  });

  it('Escape closes it like No', () => {
    alternative().click();
    keyboard('keydown', 'Escape', yes());
    expect(confirm().hidden).toBe(true);
    expect(document.activeElement).toBe(alternative());
  });

  it('keeps the background disabled across telemetry ticks', () => {
    alternative().click();
    store.update({ deviceStatus: { lastUpdate: 1 } });
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);
  });

  it('ignores key repeat from the press that opened it', () => {
    alternative().click();
    expect(keyboard('keydown', 'Enter', yes(), { repeat: true }).defaultPrevented).toBe(true);
    expect(keyboard('keydown', 'Enter', yes()).defaultPrevented).toBe(false);
  });

  it('closes without taking focus when another alert takes over', () => {
    alternative().click();
    sos.trigger({ reason: 'manual' });
    expect(confirm().hidden).toBe(true);
    expect(document.activeElement).toBe(cancelButton());
  });

  it('follows the language', () => {
    setLanguage('en');
    expect(alternative().textContent).toBe('Request help');
    expect(yes().textContent).toBe('Yes, get help');
    expect(query('.sos-confirm__title').textContent).toBe('Get help?');
  });
});

describe('vibration', () => {
  afterEach(() => {
    delete navigator.vibrate;
  });

  it('vibrates when the hold starts and on activation, if available', () => {
    const vibrate = vi.fn();
    Object.defineProperty(navigator, 'vibrate', { value: vibrate, configurable: true });

    pointer('pointerdown');
    expect(vibrate).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(HOLD);
    expect(vibrate).toHaveBeenCalledTimes(2);
  });

  it('works without vibration support', () => {
    expect(navigator.vibrate).toBeUndefined();
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD);
    expect(overlay().hidden).toBe(false);
  });
});

describe('SOS active screen', () => {
  beforeEach(() => {
    sosButton().focus();
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD);
  });

  it('shows the message and moves focus to Cancel', () => {
    expect(query('.sos-screen__title').textContent).toBe('Pidiendo ayuda…');
    expect(cancelButton().textContent).toBe('Cancelar');
    expect(document.activeElement).toBe(cancelButton());
  });

  it('is announced as a modal alert and disables what is behind it', () => {
    expect(overlay().getAttribute('role')).toBe('alertdialog');
    expect(overlay().getAttribute('aria-modal')).toBe('true');
    expect(document.getElementById(overlay().getAttribute('aria-labelledby')).textContent).toBe(
      'Pidiendo ayuda…',
    );
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);
  });

  it('stays open across telemetry ticks', () => {
    store.update({ deviceStatus: { lastUpdate: 1 }, heartRate: 90 });
    expect(overlay().hidden).toBe(false);
    expect(document.activeElement).toBe(cancelButton());
    expect(store.getState().deviceStatus.mode).toBe('sos');
  });

  it('cancel restores monitoring, the watchface and focus', () => {
    cancelButton().click();

    expect(store.getState().deviceStatus.mode).toBe('monitoring');
    expect(overlay().hidden).toBe(true);
    expect(query('.watchface__bottom').hasAttribute('inert')).toBe(false);
    expect(document.activeElement).toBe(sosButton());
  });

  it('can be activated again after cancelling', () => {
    cancelButton().click();
    pointer('pointerdown');
    vi.advanceTimersByTime(HOLD);
    expect(overlay().hidden).toBe(false);
  });
});

describe('accessibility', () => {
  const announcer = () => query('[aria-live="polite"]');

  it('labels the watchface, clock and SOS button', () => {
    expect(face.getAttribute('role')).toBe('group');
    expect(face.getAttribute('aria-label')).toBe('Pantalla del reloj');
    expect(query('.watch-clock').getAttribute('role')).toBe('timer');
    expect(sosButton().getAttribute('aria-label')).toContain('SOS');
    expect(sosButton().getAttribute('aria-label')).toContain('2 segundos');
  });

  it('hides decorative icons from screen readers', () => {
    for (const svg of face.querySelectorAll('svg')) {
      expect(svg.getAttribute('aria-hidden')).toBe('true');
    }
  });

  it('has a single live region', () => {
    expect(face.querySelectorAll('[aria-live]')).toHaveLength(1);
  });

  it('stays silent for routine readings', () => {
    store.update({
      heartRate: 77,
      battery: { level: 80 },
      accelerometer: { x: 0.01 },
      gps: { lat: 4.61 },
    });
    expect(announcer().textContent).toBe('');
  });

  it('announces status changes in the current language', () => {
    store.update({ battery: { level: 20 } });
    expect(announcer().textContent).toBe('Batería baja');

    setLanguage('en');
    store.update({ gps: { signal: false } });
    expect(announcer().textContent).toBe('GPS signal lost');
  });
});

describe('language switch', () => {
  it('updates every text without recreating the watchface', () => {
    const sosLabel = query('.sos-button__label');
    expect(sosLabel.textContent).toBe('AUXILIO');
    expect(query('.heart-rate__unit').textContent).toBe('LPM');
    expect(query('.battery-indicator__value').textContent).toBe('100 %');

    setLanguage('en');

    expect(query('.sos-button__label')).toBe(sosLabel);
    expect(sosLabel.textContent).toBe('HELP');
    expect(query('.heart-rate__unit').textContent).toBe('BPM');
    expect(query('.heart-rate').getAttribute('aria-label')).toBe('70 beats per minute');
    expect(query('.battery-indicator__value').textContent).toBe('100%');
    expect(query('.watch-clock__date').textContent).toContain('Nov');
    expect(query('.sos-screen__title').textContent).toBe('Calling for help…');
    expect(cancelButton().textContent).toBe('Cancel');
    expect(face.getAttribute('aria-label')).toBe('Watch screen');
    expect(sosButton().getAttribute('aria-label')).toContain('2 seconds');
  });
});
