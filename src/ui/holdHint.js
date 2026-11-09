import { sosConfig } from '../config/sos.config.js';
import { onLanguageChange, t } from '../i18n/index.js';

// Tells the user that SOS needs a long press, for a moment after a press that was too short.
export function createHoldHint({ announce }) {
  const root = document.createElement('p');
  root.className = 'hold-hint';
  root.hidden = true;

  let timer = null;

  const hide = () => {
    clearTimeout(timer);
    timer = null;
    root.hidden = true;
  };

  const show = () => {
    clearTimeout(timer);
    root.hidden = false;
    announce(root.textContent);
    timer = setTimeout(hide, sosConfig.holdHintDurationMs);
  };

  const render = () => {
    root.textContent = t('sos.holdHint');
  };
  onLanguageChange(render);
  render();

  return { root, show, hide };
}
