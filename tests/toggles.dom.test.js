// @vitest-environment jsdom
import { beforeEach, describe, expect, it } from 'vitest';
import { getLanguage, setLanguage } from '../src/i18n/index.js';
import { createLanguageToggle } from '../src/ui/languageToggle.js';
import { createThemeToggle } from '../src/ui/themeToggle.js';

const root = document.documentElement;

beforeEach(() => {
  setLanguage('es');
  localStorage.clear();
  root.removeAttribute('data-theme');
});

describe('theme toggle', () => {
  it('starts in light theme and offers the dark theme', () => {
    const button = createThemeToggle();
    expect(root.getAttribute('data-theme')).toBe('light');
    expect(button.textContent).toBe('Tema oscuro');
  });

  it('switches theme on click, updates its text and saves the choice', () => {
    const button = createThemeToggle();

    button.click();
    expect(root.getAttribute('data-theme')).toBe('dark');
    expect(button.textContent).toBe('Tema claro');
    expect(localStorage.getItem('elderguard.theme')).toBe('dark');

    button.click();
    expect(root.getAttribute('data-theme')).toBe('light');
    expect(button.textContent).toBe('Tema oscuro');
    expect(localStorage.getItem('elderguard.theme')).toBe('light');
  });

  it('restores a saved theme', () => {
    localStorage.setItem('elderguard.theme', 'dark');
    const button = createThemeToggle();
    expect(root.getAttribute('data-theme')).toBe('dark');
    expect(button.textContent).toBe('Tema claro');
  });

  it('does not save anything until the user chooses', () => {
    createThemeToggle();
    expect(localStorage.getItem('elderguard.theme')).toBeNull();
  });

  it('updates its text when the language changes', () => {
    const button = createThemeToggle();
    setLanguage('en');
    expect(button.textContent).toBe('Dark theme');
  });
});

describe('language toggle', () => {
  const buttons = (group) => [...group.querySelectorAll('button')];

  it('shows ES and EN as an accessible group with Spanish selected', () => {
    const group = createLanguageToggle();
    const [es, en] = buttons(group);

    expect(group.getAttribute('role')).toBe('group');
    expect(group.getAttribute('aria-label')).toBe('Idioma');
    expect(es.textContent).toBe('ES');
    expect(en.textContent).toBe('EN');
    expect(es.getAttribute('aria-label')).toBe('Español');
    expect(en.getAttribute('aria-label')).toBe('Inglés');
    expect(es.getAttribute('aria-pressed')).toBe('true');
    expect(en.getAttribute('aria-pressed')).toBe('false');
  });

  it('switches language on click and updates the document and labels', () => {
    const group = createLanguageToggle();
    const [es, en] = buttons(group);

    en.click();

    expect(getLanguage()).toBe('en');
    expect(root.getAttribute('lang')).toBe('en');
    expect(localStorage.getItem('elderguard.language')).toBe('en');
    expect(group.getAttribute('aria-label')).toBe('Language');
    expect(es.getAttribute('aria-label')).toBe('Spanish');
    expect(es.getAttribute('aria-pressed')).toBe('false');
    expect(en.getAttribute('aria-pressed')).toBe('true');
  });

  it('switches back to Spanish', () => {
    const [es, en] = buttons(createLanguageToggle());
    en.click();
    es.click();
    expect(getLanguage()).toBe('es');
    expect(es.getAttribute('aria-pressed')).toBe('true');
  });

  it('reflects a language changed elsewhere', () => {
    const [es, en] = buttons(createLanguageToggle());
    setLanguage('en');
    expect(es.getAttribute('aria-pressed')).toBe('false');
    expect(en.getAttribute('aria-pressed')).toBe('true');
  });
});
