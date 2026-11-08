import { afterEach, describe, expect, it, vi } from 'vitest';
import { DEFAULT_THEME, getNextTheme, loadTheme, saveTheme } from '../src/ui/themeToggle.js';

function stubStorage(initial = {}) {
  const data = new Map(Object.entries(initial));
  vi.stubGlobal('localStorage', {
    getItem: (key) => data.get(key) ?? null,
    setItem: (key, value) => data.set(key, String(value)),
  });
}

function stubBrokenStorage() {
  const fail = () => {
    throw new Error('storage unavailable');
  };
  vi.stubGlobal('localStorage', { getItem: fail, setItem: fail });
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('getNextTheme', () => {
  it('switches between light and dark', () => {
    expect(getNextTheme('dark')).toBe('light');
    expect(getNextTheme('light')).toBe('dark');
  });
});

describe('loadTheme', () => {
  it('defaults to light on first load, even when the system prefers dark', () => {
    stubStorage();
    vi.stubGlobal('matchMedia', () => ({ matches: true }));
    expect(DEFAULT_THEME).toBe('light');
    expect(loadTheme()).toBe('light');
  });

  it('ignores invalid saved values', () => {
    stubStorage({ 'elderguard.theme': 'purple' });
    expect(loadTheme()).toBe('light');
  });

  it('falls back to light when storage is unavailable', () => {
    stubBrokenStorage();
    expect(loadTheme()).toBe('light');
  });
});

describe('saveTheme', () => {
  it('persists the choice so the next load restores it', () => {
    stubStorage();
    saveTheme('dark');
    expect(loadTheme()).toBe('dark');
  });

  it('does not throw when storage is unavailable', () => {
    stubBrokenStorage();
    expect(() => saveTheme('dark')).not.toThrow();
  });
});
