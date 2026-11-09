// @vitest-environment jsdom
import { beforeEach, describe, expect, it, vi } from 'vitest';
import html from '../index.html?raw';
import { saveTheme } from '../src/ui/themeToggle.js';

const head = html.slice(0, html.indexOf('</head>'));
const inlineScript = head.match(/<script>([\s\S]*?)<\/script>/)[1];
const runInlineScript = new Function(inlineScript);
const root = document.documentElement;

beforeEach(() => {
  localStorage.clear();
  root.removeAttribute('data-theme');
  vi.unstubAllGlobals();
});

describe('theme preload script', () => {
  it('runs in the head, before any module script', () => {
    expect(head).not.toContain('type="module"');
    expect(head).toContain('<script>');
  });

  it('applies the theme saved by the theme toggle', () => {
    saveTheme('dark');
    runInlineScript();
    expect(root.getAttribute('data-theme')).toBe('dark');
  });

  it('leaves the default theme alone when nothing is saved', () => {
    runInlineScript();
    expect(root.hasAttribute('data-theme')).toBe(false);
  });

  it('ignores invalid saved values', () => {
    localStorage.setItem('elderguard.theme', 'purple');
    runInlineScript();
    expect(root.hasAttribute('data-theme')).toBe(false);
  });

  it('does not throw when storage is unavailable', () => {
    vi.stubGlobal('localStorage', {
      getItem() {
        throw new Error('storage unavailable');
      },
    });
    expect(runInlineScript).not.toThrow();
    expect(root.hasAttribute('data-theme')).toBe(false);
  });
});
