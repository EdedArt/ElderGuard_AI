import { onLanguageChange, t } from '../i18n/index.js';

// Groups of controls are fieldsets, so a screen reader names the group on entering it. Sections
// that only show information are plain labelled regions.
export function createPanelSection(titleKey, { controls = false } = {}) {
  const root = document.createElement(controls ? 'fieldset' : 'section');
  root.className = 'simulator-section';

  const title = document.createElement(controls ? 'legend' : 'h3');
  title.className = 'simulator-section__title';
  if (!controls) {
    title.id = titleKey.replaceAll('.', '-');
    root.setAttribute('aria-labelledby', title.id);
  }
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
