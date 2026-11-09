import { sosConfig } from '../config/sos.config.js';
import { createLongPress } from '../core/longPress.js';
import { onLanguageChange, t } from '../i18n/index.js';

const ACTIVATION_KEYS = ['Enter', ' '];
const VIBRATION_HOLD_START = 50;
const VIBRATION_ACTIVATED = [200, 100, 200];

const PROGRESS_RING = `
  <svg class="sos-button__ring" viewBox="0 0 100 100" aria-hidden="true" focusable="false">
    <circle class="sos-button__ring-progress" cx="50" cy="50" r="46" pathLength="100" />
  </svg>
`;

function vibrate(pattern) {
  if (typeof navigator.vibrate === 'function') navigator.vibrate(pattern);
}

// Activation moves focus to another button while the key is still down. Without this, key
// repeat or the release would press that button too, cancelling the alert straight away.
function ignoreKeyUntilReleased(key) {
  const ignore = (event) => {
    if (event.key !== key) return;
    event.preventDefault();
    event.stopPropagation();
    if (event.type === 'keyup') {
      window.removeEventListener('keydown', ignore, true);
      window.removeEventListener('keyup', ignore, true);
    }
  };
  window.addEventListener('keydown', ignore, true);
  window.addEventListener('keyup', ignore, true);
}

export function createSosButton({ onActivate = () => {} } = {}) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'sos-button';
  button.style.setProperty('--sos-hold-duration', `${sosConfig.holdDurationMs}ms`);
  button.innerHTML = PROGRESS_RING;

  const title = document.createElement('span');
  title.className = 'sos-button__title';
  const label = document.createElement('span');
  label.className = 'sos-button__label';
  button.append(title, label);

  let heldKey = null;

  const endHold = () => {
    press.cancel();
    heldKey = null;
    button.classList.remove('sos-button--holding');
  };

  const press = createLongPress({
    durationMs: sosConfig.holdDurationMs,
    onComplete() {
      const releasedKey = heldKey;
      endHold();
      vibrate(VIBRATION_ACTIVATED);
      if (releasedKey !== null) ignoreKeyUntilReleased(releasedKey);
      onActivate();
    },
  });

  const startHold = () => {
    if (press.isActive()) return;
    press.start();
    button.classList.add('sos-button--holding');
    vibrate(VIBRATION_HOLD_START);
  };

  button.addEventListener('pointerdown', (event) => {
    if (event.button === 0) startHold();
  });
  for (const type of ['pointerup', 'pointerleave', 'pointercancel', 'blur']) {
    button.addEventListener(type, endHold);
  }
  // A long touch would otherwise open the browser's context menu and interrupt the hold.
  button.addEventListener('contextmenu', (event) => event.preventDefault());

  button.addEventListener('keydown', (event) => {
    if (!ACTIVATION_KEYS.includes(event.key)) return;
    event.preventDefault();
    if (event.repeat || press.isActive()) return;
    heldKey = event.key;
    startHold();
  });
  button.addEventListener('keyup', (event) => {
    if (!ACTIVATION_KEYS.includes(event.key)) return;
    event.preventDefault();
    if (event.key === heldKey) endHold();
  });

  const render = () => {
    title.textContent = t('sos.title');
    label.textContent = t('sos.label');
  };

  onLanguageChange(render);
  render();

  return button;
}
