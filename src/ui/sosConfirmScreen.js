import { onLanguageChange, t } from '../i18n/index.js';

const TITLE_ID = 'sos-confirm-title';
const ACTIVATION_KEYS = ['Enter', ' '];

function createAnswerButton(className, onClick) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = className;
  button.addEventListener('click', onClick);
  return button;
}

// The press that opened this screen may still be down, and must not answer the question too.
function ignoreKeyRepeat(event) {
  if (event.repeat && ACTIVATION_KEYS.includes(event.key)) event.preventDefault();
}

// Confirmation for the screen reader alternative to the SOS long press.
export function createSosConfirmScreen({ store, lock, onConfirm, returnFocusTo }) {
  const root = document.createElement('div');
  root.className = 'sos-confirm';
  root.hidden = true;
  root.setAttribute('role', 'alertdialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-labelledby', TITLE_ID);

  const close = ({ restoreFocus }) => {
    root.hidden = true;
    lock.set('sos-confirm', false);
    if (restoreFocus) returnFocusTo().focus();
  };

  const title = document.createElement('p');
  title.id = TITLE_ID;
  title.className = 'sos-confirm__title';
  const yes = createAnswerButton('sos-confirm__yes', () => {
    close({ restoreFocus: false });
    onConfirm();
  });
  const no = createAnswerButton('sos-confirm__no', () => close({ restoreFocus: true }));
  root.append(title, yes, no);

  root.addEventListener('keydown', (event) => {
    ignoreKeyRepeat(event);
    if (event.key === 'Escape') close({ restoreFocus: true });
  });

  // Another alert takes over the watch, and with it the focus.
  store.subscribe((state, changedKeys) => {
    if (!root.hidden && changedKeys.includes('deviceStatus')) {
      if (state.deviceStatus.mode !== 'monitoring') close({ restoreFocus: false });
    }
  });

  const render = () => {
    title.textContent = t('sos.confirm.title');
    yes.textContent = t('sos.confirm.yes');
    no.textContent = t('sos.confirm.no');
  };
  onLanguageChange(render);
  render();

  return {
    root,
    open() {
      root.hidden = false;
      lock.set('sos-confirm', true);
      yes.focus();
    },
  };
}
