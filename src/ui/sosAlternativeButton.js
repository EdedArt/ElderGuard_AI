import { onLanguageChange, t } from '../i18n/index.js';

// A long press is hard to perform with a screen reader, so assistive technology gets this button.
// It stays out of sight unless focused, so keyboard users can still see where they are.
export function createSosAlternativeButton({ onActivate }) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'sos-alternative';
  button.addEventListener('click', onActivate);

  const render = () => {
    button.textContent = t('sos.alternative');
  };
  onLanguageChange(render);
  render();

  return button;
}
