import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { onLanguageChange, t } from '../i18n/index.js';
import { vibrate } from './vibrate.js';

const VIBRATION_PER_SECOND = 200;

// The ring is the only moving part, and it tells how much time is left, so it stays with reduced
// motion. A CSS animation keeps it smooth between ticks, and it restarts whenever the overlay opens.
const DRAINING_RING = `
  <svg class="fall-overlay__ring" viewBox="0 0 100 100" aria-hidden="true" focusable="false">
    <circle class="fall-overlay__ring-track" cx="50" cy="50" r="48" />
    <circle class="fall-overlay__ring-progress" cx="50" cy="50" r="48" pathLength="100" />
  </svg>
`;

export function createFallOverlay({
  store,
  countdown,
  lock,
  onCancel,
  config = fallDetectionConfig,
}) {
  const root = document.createElement('div');
  root.className = 'fall-overlay';
  root.style.setProperty('--fall-countdown-duration', `${config.countdownSeconds}s`);
  root.innerHTML = DRAINING_RING;

  const title = document.createElement('p');
  title.className = 'fall-overlay__title';
  const seconds = document.createElement('p');
  seconds.className = 'fall-overlay__seconds';
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'fall-overlay__cancel';
  cancel.addEventListener('click', onCancel);
  root.append(title, seconds, cancel);

  const render = ({ deviceStatus }) => {
    const active = deviceStatus.mode === 'fall-countdown';
    root.hidden = !active;
    lock.set('fall', active);
  };
  const renderText = () => {
    title.textContent = t('fall.question');
    cancel.textContent = t('fall.cancel');
  };

  countdown.onTick((remaining) => {
    seconds.textContent = String(remaining);
    root.classList.toggle('fall-overlay--urgent', remaining <= config.urgentSeconds);
    if (remaining > 0) vibrate(VIBRATION_PER_SECOND);
  });
  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('deviceStatus')) render(state);
  });
  onLanguageChange(renderText);
  render(store.getState());
  renderText();

  return root;
}
