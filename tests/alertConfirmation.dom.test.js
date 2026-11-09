// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { contactsConfig } from '../src/config/contacts.config.js';
import { heartRateAnomalyConfig } from '../src/config/heartRateAnomaly.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { setLanguage } from '../src/i18n/index.js';
import { createWatchface } from '../src/ui/watchface.js';

const TICK = telemetryConfig.tickIntervalMs;
const TIME_TO_WARN = heartRateAnomalyConfig.sustainedDurationMs + TICK;
const STILL = { x: 0, y: 0, z: 1 };

let device;
let face;

const query = (selector) => face.querySelector(selector);
const details = () => query('.sos-screen__details');
const banner = () => query('.heart-rate-banner');
const announcer = () => query('[role="status"]');

function holdCriticalRate() {
  device.engine.setOverride('accelerometer', STILL);
  device.engine.setOverride('heartRate', 170);
  vi.advanceTimersByTime(TIME_TO_WARN);
}

beforeEach(() => {
  vi.useFakeTimers();
  localStorage.clear();
  setLanguage('es');
  device = createDevice({ createAudioContext: () => null });
  face = createWatchface({ ...device, onStart: device.start });
  document.body.replaceChildren(face);
  query('.start-screen__button').click();
  vi.advanceTimersByTime(TICK);
});

afterEach(() => {
  device.engine.stop();
  vi.useRealTimers();
});

describe('SOS screen', () => {
  it('shows nothing about an alert before there is one', () => {
    expect(details().hidden).toBe(true);
  });

  it('shows the contacts notified and the coordinates sent', () => {
    device.sos.trigger({ reason: 'manual' });
    const { lat, lng } = device.store.getState().gps;

    expect(details().hidden).toBe(false);
    expect(details().textContent).toContain('Avisados (simulado)');
    for (const { name } of contactsConfig) expect(details().textContent).toContain(name);
    expect(query('.sos-screen__location').textContent).toBe(
      `GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}`,
    );
  });

  it('says so when the coordinates are only the last known ones', () => {
    device.engine.setOverride('gps', { signal: false });
    device.sos.trigger({ reason: 'manual' });
    expect(query('.sos-screen__location').textContent).toMatch(/^Última posición: /);
  });

  it('keeps showing the coordinates that were sent, not the current ones', () => {
    device.engine.setOverride('gps', { lat: 1, lng: 2 });
    device.sos.trigger({ reason: 'manual' });
    device.engine.setOverride('gps', { lat: 3, lng: 4 });

    expect(query('.sos-screen__location').textContent).toBe('GPS: 1.00000, 2.00000');
  });

  it('is announced, keeping the focus on the cancel button', () => {
    device.sos.trigger({ reason: 'manual' });
    expect(announcer().textContent).toContain(contactsConfig[0].name);
    expect(document.activeElement).toBe(query('.sos-screen__cancel'));
    expect(query('.sos-screen').getAttribute('aria-describedby')).toBe(details().id);
  });

  it('follows the language', () => {
    device.sos.trigger({ reason: 'manual' });
    setLanguage('en');
    expect(details().textContent).toContain('Notified (mock)');
  });

  it('forgets the alert when the SOS ends', () => {
    device.sos.trigger({ reason: 'manual' });
    device.sos.cancel();
    expect(details().hidden).toBe(true);
  });

  it('is not taken over by a critical heart rate alert during the SOS', () => {
    device.engine.setOverride('gps', { lat: 1, lng: 2 });
    device.sos.trigger({ reason: 'manual' });
    device.engine.setOverride('gps', { lat: 3, lng: 4 });
    holdCriticalRate();

    expect(device.alerts.getAlerts()).toHaveLength(2);
    expect(query('.sos-screen__location').textContent).toBe('GPS: 1.00000, 2.00000');
  });
});

describe('heart rate banner for a critical alert', () => {
  it('is hidden, and not critical, in normal readings', () => {
    expect(banner().hidden).toBe(true);
    expect(banner().classList.contains('heart-rate-banner--critical')).toBe(false);
  });

  it('says that the alert went out, without opening any screen', () => {
    holdCriticalRate();

    expect(banner().hidden).toBe(false);
    expect(banner().classList.contains('heart-rate-banner--critical')).toBe(true);
    expect(banner().textContent.trim()).toBe('Ritmo crítico: familia avisada');
    expect(announcer().textContent).toBe('Ritmo crítico: familia avisada');
    expect(query('.sos-screen').hidden).toBe(true);
    expect(query('.fall-overlay').hidden).toBe(true);
  });

  it('goes back to the plain warning if the rate stays high but stops being critical', () => {
    holdCriticalRate();
    device.engine.setOverride('heartRate', 140);

    expect(banner().hidden).toBe(false);
    expect(banner().classList.contains('heart-rate-banner--critical')).toBe(false);
    expect(banner().textContent.trim()).toBe('Ritmo cardíaco alto en reposo');
  });

  it('goes away when the rate is normal again', () => {
    holdCriticalRate();
    device.engine.setOverride('heartRate', 70);
    expect(banner().hidden).toBe(true);
  });

  it('follows the language', () => {
    holdCriticalRate();
    setLanguage('en');
    expect(banner().textContent.trim()).toBe('Critical heart rate: family notified');
  });
});
