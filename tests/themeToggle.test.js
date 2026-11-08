import { describe, expect, it } from 'vitest';
import { getNextTheme } from '../src/ui/themeToggle.js';

describe('getNextTheme', () => {
  it('switches away from the system theme when no theme is set', () => {
    expect(getNextTheme(null, true)).toBe('light');
    expect(getNextTheme(null, false)).toBe('dark');
  });

  it('switches away from the explicit theme regardless of the system', () => {
    expect(getNextTheme('dark', false)).toBe('light');
    expect(getNextTheme('light', true)).toBe('dark');
  });
});
