export function getNextTheme(currentTheme, systemPrefersDark) {
  const activeTheme = currentTheme ?? (systemPrefersDark ? 'dark' : 'light');
  return activeTheme === 'dark' ? 'light' : 'dark';
}

export function createThemeToggle() {
  const root = document.documentElement;
  const systemDark = window.matchMedia('(prefers-color-scheme: dark)');

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'theme-toggle';

  const nextTheme = () => getNextTheme(root.getAttribute('data-theme'), systemDark.matches);
  const renderLabel = () => {
    button.textContent = nextTheme() === 'dark' ? 'Dark theme' : 'Light theme';
  };

  button.addEventListener('click', () => {
    root.setAttribute('data-theme', nextTheme());
    renderLabel();
  });
  systemDark.addEventListener('change', renderLabel);
  renderLabel();

  return button;
}
