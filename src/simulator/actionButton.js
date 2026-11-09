import { onLanguageChange, t } from '../i18n/index.js';

// `labelKey` can be a function, for a button whose label depends on the state.
export function createActionButton({ action, labelKey, onClick, gate }) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'simulator-action';
  button.dataset.action = action;
  button.addEventListener('click', onClick);
  gate.add(button);

  const render = () => {
    button.textContent = t(typeof labelKey === 'function' ? labelKey() : labelKey);
  };
  onLanguageChange(render);
  render();

  return { button, render };
}
