const STORAGE_KEY = 'elderguard.theme';
const THEMES = ['light', 'dark'];

export const DEFAULT_THEME = 'light';

export function loadTheme() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return THEMES.includes(saved) ? saved : DEFAULT_THEME;
  } catch {
    return DEFAULT_THEME;
  }
}

export function saveTheme(theme) {
  try {
    localStorage.setItem(STORAGE_KEY, theme);
  } catch {
    // Storage can be unavailable; the choice then only lasts until reload.
  }
}

export function getNextTheme(currentTheme) {
  return currentTheme === 'dark' ? 'light' : 'dark';
}

export function createThemeToggle() {
  const root = document.documentElement;
  let theme = loadTheme();

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'theme-toggle';

  const render = () => {
    root.setAttribute('data-theme', theme);
    button.textContent = getNextTheme(theme) === 'dark' ? 'Dark theme' : 'Light theme';
  };

  button.addEventListener('click', () => {
    theme = getNextTheme(theme);
    saveTheme(theme);
    render();
  });
  render();

  return button;
}
