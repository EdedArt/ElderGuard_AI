import { describe, expect, it } from 'vitest';
import { magnitude } from '../src/core/magnitude.js';

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
