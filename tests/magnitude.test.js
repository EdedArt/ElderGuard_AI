import { describe, expect, it } from 'vitest';
import { isAtRest, magnitude } from '../src/core/magnitude.js';

describe('magnitude', () => {
  it('is the Euclidean norm of the three axes', () => {
    expect(magnitude({ x: 3, y: 4, z: 0 })).toBe(5);
    expect(magnitude({ x: 2, y: 3, z: 6 })).toBe(7);
  });

  it('is 1 g for a watch at rest, whichever axis gravity falls on', () => {
    expect(magnitude({ x: 0, y: 0, z: 1 })).toBe(1);
    expect(magnitude({ x: 1, y: 0, z: 0 })).toBe(1);
  });

  it('ignores the sign of each axis', () => {
    expect(magnitude({ x: -3, y: 4, z: 0 })).toBe(5);
  });

  it('is 0 in free fall', () => {
    expect(magnitude({ x: 0, y: 0, z: 0 })).toBe(0);
  });
});

describe('isAtRest', () => {
  it('accepts about 1 g in any orientation', () => {
    expect(isAtRest({ x: 0, y: 0, z: 1 }, 0.15)).toBe(true);
    expect(isAtRest({ x: 1, y: 0, z: 0 }, 0.15)).toBe(true);
    expect(isAtRest({ x: 0, y: 0, z: 1.1 }, 0.15)).toBe(true);
  });

  it('rejects readings off 1 g by more than the tolerance', () => {
    expect(isAtRest({ x: 0, y: 0, z: 1.2 }, 0.15)).toBe(false);
    expect(isAtRest({ x: 0, y: 0, z: 0.8 }, 0.15)).toBe(false);
  });
});
