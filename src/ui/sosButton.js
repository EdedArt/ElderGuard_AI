import { onLanguageChange, t } from '../i18n/index.js';

export function createSosButton() {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'sos-button';

  const title = document.createElement('span');
  title.className = 'sos-button__title';
  const label = document.createElement('span');
  label.className = 'sos-button__label';
  button.append(title, label);

  const render = () => {
    title.textContent = t('sos.title');
    label.textContent = t('sos.label');
  };

  onLanguageChange(render);
  render();

  return button;
}
