import { describe, expect, it } from 'vitest';
import { contactsConfig } from '../src/config/contacts.config.js';
import { buildAlertPayload } from '../src/core/alertPayload.js';

const STATE = {
  heartRate: 88,
  accelerometer: { x: 0, y: 0, z: 1 },
  gps: { lat: 4.6097, lng: -74.0817, accuracy: 5, signal: true },
  battery: { level: 42.6, charging: false },
  deviceStatus: { mode: 'sos', lastUpdate: 1, healthAlert: null },
};

const build = (reason, extra = {}) =>
  buildAlertPayload({ state: STATE, reason, timestamp: 12345, ...extra });

describe('buildAlertPayload', () => {
  it.each([
    ['fall', 'fall'],
    ['manual', 'manual-sos'],
    ['high-heart-rate', 'high-heart-rate'],
  ])('maps the reason %s to the type %s', (reason, type) => {
    expect(build(reason).type).toBe(type);
  });

  it('has exactly the agreed shape, from the state given', () => {
    expect(build('fall')).toEqual({
      type: 'fall',
      timestamp: 12345,
      gps: STATE.gps,
      heartRate: 88,
      batteryLevel: 43,
      contacts: contactsConfig,
    });
  });

  it('uses the contacts it is given', () => {
    const contacts = [{ name: 'Test', relationship: 'son', phone: '555-0199' }];
    expect(build('fall', { contacts }).contacts).toEqual(contacts);
  });

  it('keeps the last position and says the signal was lost', () => {
    const state = { ...STATE, gps: { ...STATE.gps, signal: false } };
    const alert = buildAlertPayload({ state, reason: 'fall', timestamp: 1 });
    expect(alert.gps.signal).toBe(false);
    expect(alert.gps.lat).toBe(STATE.gps.lat);
  });

  it('shares nothing with its sources', () => {
    const alert = build('fall');
    alert.gps.lat = 0;
    alert.contacts[0].name = 'Changed';

    expect(STATE.gps.lat).toBe(4.6097);
    expect(contactsConfig[0].name).not.toBe('Changed');
  });

  it('does not change the state', () => {
    const before = structuredClone(STATE);
    build('fall');
    expect(STATE).toEqual(before);
  });

  it.each(['unknown', 'toString', undefined])('rejects the reason %s', (reason) => {
    expect(() => build(reason)).toThrow('Unknown alert reason');
  });
});

describe('demo contacts', () => {
  it('has two or three, all complete', () => {
    expect(contactsConfig.length).toBeGreaterThanOrEqual(2);
    expect(contactsConfig.length).toBeLessThanOrEqual(3);
    for (const contact of contactsConfig) {
      expect(contact).toEqual({
        name: expect.any(String),
        relationship: expect.any(String),
        phone: expect.stringMatching(/^555-01\d\d$/),
      });
    }
  });
});
