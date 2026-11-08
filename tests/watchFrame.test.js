import { describe, expect, it } from 'vitest';
import { clampWatchSize } from '../src/ui/watchFrame.js';

describe('clampWatchSize', () => {
  it('keeps sizes inside the allowed range', () => {
    expect(clampWatchSize(410)).toBe(410);
    expect(clampWatchSize(390)).toBe(390);
    expect(clampWatchSize(454)).toBe(454);
  });

  it('clamps sizes outside the allowed range', () => {
    expect(clampWatchSize(100)).toBe(390);
    expect(clampWatchSize(1000)).toBe(454);
  });

  it('falls back to the default for invalid sizes', () => {
    expect(clampWatchSize(Number.NaN)).toBe(410);
    expect(clampWatchSize('big')).toBe(410);
  });
});
