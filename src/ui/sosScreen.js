import { onLanguageChange, t } from '../i18n/index.js';

const TITLE_ID = 'sos-screen-title';

export function createSosScreen({ store, onCancel, background, returnFocusTo }) {
  const root = document.createElement('div');
  root.className = 'sos-screen';
  root.setAttribute('role', 'alertdialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-labelledby', TITLE_ID);

  const title = document.createElement('p');
  title.id = TITLE_ID;
  title.className = 'sos-screen__title';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'sos-screen__cancel';
  cancel.addEventListener('click', onCancel);
  root.append(title, cancel);

  let active = false;

  const render = ({ deviceStatus }) => {
    const nextActive = deviceStatus.mode === 'sos';
    root.hidden = !nextActive;
    for (const element of background) element.toggleAttribute('inert', nextActive);

    if (nextActive !== active) (nextActive ? cancel : returnFocusTo).focus();
    active = nextActive;
  };
  const renderText = () => {
    title.textContent = t('sos.active');
    cancel.textContent = t('sos.cancel');
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('deviceStatus')) render(state);
  });
  onLanguageChange(renderText);
  render(store.getState());
  renderText();

  return root;
}
