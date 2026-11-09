import { onLanguageChange, t } from '../i18n/index.js';

// Browsers keep audio locked until a user gesture, and the fall alert needs its sound. This first
// tap provides that gesture, and the watch does not begin working before it.
export function createStartScreen({ lock, onStart, returnFocusTo }) {
  const root = document.createElement('div');
  root.className = 'start-screen';

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'start-screen__button';
  // Focused on load, so a keyboard or screen reader user lands on the only available action.
  button.autofocus = true;
  button.addEventListener('click', () => {
    root.hidden = true;
    lock.set('start', false);
    returnFocusTo.focus();
    onStart();
  });
  root.append(button);

  lock.set('start', true);

  const render = () => {
    button.textContent = t('start.button');
  };
  onLanguageChange(render);
  render();

  return root;
}
