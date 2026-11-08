import { afterEach, describe, expect, it, vi } from 'vitest';
import { en } from '../src/i18n/en.js';
import { es } from '../src/i18n/es.js';

const STORAGE_KEY = 'elderguard.language';

function stubStorage(initial = {}) {
  const data = new Map(Object.entries(initial));
  vi.stubGlobal('localStorage', {
    getItem: (key) => data.get(key) ?? null,
    setItem: (key, value) => data.set(key, String(value)),
  });
  return data;
}

function stubDocument() {
  const attributes = new Map();
  vi.stubGlobal('document', {
    documentElement: { setAttribute: (name, value) => attributes.set(name, value) },
  });
  return attributes;
}

// The module reads the saved language on import, so each test gets a fresh copy.
async function loadI18n() {
  vi.resetModules();
  return import('../src/i18n/index.js');
}

function flattenKeys(node, prefix = '') {
  return Object.entries(node).flatMap(([key, value]) =>
    typeof value === 'string' ? [`${prefix}${key}`] : flattenKeys(value, `${prefix}${key}.`),
  );
}

afterEach(() => {
  vi.doUnmock('../src/i18n/en.js');
  vi.doUnmock('../src/i18n/es.js');
  vi.unstubAllGlobals();
});

describe('default language', () => {
  it('is Spanish on first load', async () => {
    stubStorage();
    const attributes = stubDocument();
    const { getLanguage, t } = await loadI18n();
    expect(getLanguage()).toBe('es');
    expect(t('theme.toDark')).toBe(es.theme.toDark);
    expect(attributes.get('lang')).toBe('es');
  });

  it('is Spanish when the saved value is invalid', async () => {
    stubStorage({ [STORAGE_KEY]: 'constructor' });
    const { getLanguage } = await loadI18n();
    expect(getLanguage()).toBe('es');
  });
});

describe('setLanguage', () => {
  it('switches the translations and the lang attribute', async () => {
    stubStorage();
    const attributes = stubDocument();
    const { getLanguage, setLanguage, t } = await loadI18n();
    setLanguage('en');
    expect(getLanguage()).toBe('en');
    expect(t('theme.toDark')).toBe(en.theme.toDark);
    expect(attributes.get('lang')).toBe('en');
  });

  it('ignores unsupported languages', async () => {
    stubStorage();
    const { getLanguage, setLanguage } = await loadI18n();
    setLanguage('fr');
    expect(getLanguage()).toBe('es');
  });
});

describe('onLanguageChange', () => {
  it('notifies listeners until they unsubscribe', async () => {
    stubStorage();
    const { onLanguageChange, setLanguage } = await loadI18n();
    const listener = vi.fn();
    const unsubscribe = onLanguageChange(listener);

    setLanguage('en');
    expect(listener).toHaveBeenCalledTimes(1);
    expect(listener).toHaveBeenCalledWith('en');

    unsubscribe();
    setLanguage('es');
    expect(listener).toHaveBeenCalledTimes(1);
  });

  it('does not notify when the language stays the same', async () => {
    stubStorage();
    const { onLanguageChange, setLanguage } = await loadI18n();
    const listener = vi.fn();
    onLanguageChange(listener);
    setLanguage('es');
    expect(listener).not.toHaveBeenCalled();
  });
});

describe('t', () => {
  it('falls back to Spanish when a key is missing in English', async () => {
    stubStorage({ [STORAGE_KEY]: 'en' });
    vi.doMock('../src/i18n/en.js', () => ({ en: { theme: { toDark: 'Dark' } } }));
    vi.doMock('../src/i18n/es.js', () => ({
      es: { theme: { toDark: 'Oscuro', toLight: 'Claro' } },
    }));
    const { t } = await loadI18n();
    expect(t('theme.toDark')).toBe('Dark');
    expect(t('theme.toLight')).toBe('Claro');
  });

  it('returns the key when it is missing in both languages', async () => {
    stubStorage();
    const { t } = await loadI18n();
    expect(t('does.not.exist')).toBe('does.not.exist');
  });

  it('returns the key for a group instead of a string', async () => {
    stubStorage();
    const { t } = await loadI18n();
    expect(t('theme')).toBe('theme');
    expect(t('theme.constructor')).toBe('theme.constructor');
  });

  it('interpolates params and keeps unknown placeholders', async () => {
    stubStorage();
    vi.doMock('../src/i18n/es.js', () => ({ es: { app: { greeting: 'Hola {name}, {other}' } } }));
    const { t } = await loadI18n();
    expect(t('app.greeting', { name: 'Ana' })).toBe('Hola Ana, {other}');
  });

  it('inserts param values literally', async () => {
    stubStorage();
    vi.doMock('../src/i18n/es.js', () => ({ es: { app: { greeting: 'Hola {name}' } } }));
    const { t } = await loadI18n();
    expect(t('app.greeting', { name: '$& {name}' })).toBe('Hola $& {name}');
  });
});

describe('persistence', () => {
  it('saves the choice and restores it on the next load', async () => {
    const data = stubStorage();
    const first = await loadI18n();
    first.setLanguage('en');
    expect(data.get(STORAGE_KEY)).toBe('en');

    const second = await loadI18n();
    expect(second.getLanguage()).toBe('en');
  });

  it('keeps working when storage is unavailable', async () => {
    const fail = () => {
      throw new Error('storage unavailable');
    };
    vi.stubGlobal('localStorage', { getItem: fail, setItem: fail });
    const { getLanguage, setLanguage } = await loadI18n();
    expect(getLanguage()).toBe('es');
    expect(() => setLanguage('en')).not.toThrow();
    expect(getLanguage()).toBe('en');
  });
});

describe('dictionaries', () => {
  it('have the same keys in Spanish and English', () => {
    expect(flattenKeys(en).sort()).toEqual(flattenKeys(es).sort());
  });
});
