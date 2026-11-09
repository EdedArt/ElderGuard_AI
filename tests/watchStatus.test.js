import { describe, expect, it } from 'vitest';
import {
  batteryPercent,
  batteryState,
  gpsState,
  heartbeatIntervalMs,
  statusChanges,
} from '../src/core/watchStatus.js';

describe('heartbeatIntervalMs', () => {
  it('converts BPM to the time between beats', () => {
    expect(heartbeatIntervalMs(60)).toBe(1000);
    expect(heartbeatIntervalMs(120)).toBe(500);
    expect(heartbeatIntervalMs(70)).toBe(857);
  });

  it('returns 0 for values that cannot be animated', () => {
    expect(heartbeatIntervalMs(0)).toBe(0);
    expect(heartbeatIntervalMs(-10)).toBe(0);
    expect(heartbeatIntervalMs(Number.NaN)).toBe(0);
    expect(heartbeatIntervalMs(null)).toBe(0);
  });
});

describe('batteryPercent', () => {
  it('rounds the level to a whole percentage', () => {
    expect(batteryPercent(99.99)).toBe(100);
    expect(batteryPercent(20.4)).toBe(20);
    expect(batteryPercent(0)).toBe(0);
  });
});

describe('batteryState', () => {
  it('is normal above 20', () => {
    expect(batteryState(100)).toBe('normal');
    expect(batteryState(21)).toBe('normal');
    expect(batteryState(20.01)).toBe('normal');
  });

  it('is low from 20 down to just above 10', () => {
    expect(batteryState(20)).toBe('low');
    expect(batteryState(11)).toBe('low');
    expect(batteryState(10.01)).toBe('low');
  });

  it('is critical at 10 and below', () => {
    expect(batteryState(10)).toBe('critical');
    expect(batteryState(1)).toBe('critical');
    expect(batteryState(0)).toBe('critical');
  });
});

describe('statusChanges', () => {
  const state = (level, signal = true) => ({ battery: { level }, gps: { signal } });

  it('reports nothing for routine changes', () => {
    expect(statusChanges(state(80), state(79))).toEqual([]);
    expect(statusChanges(state(15), state(14))).toEqual([]);
  });

  it('reports the battery crossing into low and critical', () => {
    expect(statusChanges(state(21), state(20))).toEqual(['batteryLow']);
    expect(statusChanges(state(11), state(10))).toEqual(['batteryCritical']);
  });

  it('follows the displayed percentage', () => {
    expect(statusChanges(state(20.6), state(20.4))).toEqual(['batteryLow']);
  });

  it('does not announce the battery returning to normal', () => {
    expect(statusChanges(state(15), state(50))).toEqual([]);
  });

  it('reports GPS lost and restored', () => {
    expect(statusChanges(state(80, true), state(80, false))).toEqual(['gpsLost']);
    expect(statusChanges(state(80, false), state(80, true))).toEqual(['gpsRestored']);
  });

  it('can report several changes at once', () => {
    expect(statusChanges(state(21, true), state(20, false))).toEqual(['batteryLow', 'gpsLost']);
  });
});

describe('gpsState', () => {
  it('is ok with signal and lost without it', () => {
    expect(gpsState({ signal: true })).toBe('ok');
    expect(gpsState({ signal: false })).toBe('lost');
  });
});
