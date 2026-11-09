import { onLanguageChange, t } from '../i18n/index.js';

export function createPanelSection(titleKey) {
  const root = document.createElement('section');
  root.className = 'simulator-section';

  const title = document.createElement('h3');
  title.className = 'simulator-section__title';
  const content = document.createElement('div');
  content.className = 'simulator-section__content';
  root.append(title, content);

  const render = () => {
    title.textContent = t(titleKey);
  };
  onLanguageChange(render);
  render();

  return { root, content };
}
