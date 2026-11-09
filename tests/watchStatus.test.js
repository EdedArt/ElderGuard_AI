import { describe, expect, it } from 'vitest';
import { heartbeatIntervalMs } from '../src/core/watchStatus.js';

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
