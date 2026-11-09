import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { onLanguageChange, t } from '../i18n/index.js';
import { vibrate } from './vibrate.js';

const TITLE_ID = 'fall-overlay-title';
const ACTIVATION_KEYS = ['Enter', ' '];
const VIBRATION_PER_SECOND = 200;

// The ring is the only moving part, and it tells how much time is left, so it stays with reduced
// motion. A CSS animation keeps it smooth between ticks, and it restarts whenever the overlay opens.
const DRAINING_RING = `
  <svg class="fall-overlay__ring" viewBox="0 0 100 100" aria-hidden="true" focusable="false">
    <circle class="fall-overlay__ring-track" cx="50" cy="50" r="48" />
    <circle class="fall-overlay__ring-progress" cx="50" cy="50" r="48" pathLength="100" />
  </svg>
`;

function createLiveRegion() {
  const region = document.createElement('div');
  region.className = 'visually-hidden';
  region.setAttribute('role', 'alert');
  region.setAttribute('aria-live', 'assertive');
  region.setAttribute('aria-atomic', 'true');
  return region;
}

export function createFallOverlay({
  store,
  countdown,
  lock,
  onCancel,
  returnFocusTo,
  config = fallDetectionConfig,
}) {
  const root = document.createElement('div');
  root.className = 'fall-overlay';
  root.setAttribute('role', 'alertdialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-labelledby', TITLE_ID);
  root.style.setProperty('--fall-countdown-duration', `${config.countdownSeconds}s`);
  root.innerHTML = DRAINING_RING;

  const title = document.createElement('p');
  title.id = TITLE_ID;
  title.className = 'fall-overlay__title';
  // Read aloud only through the live region, which skips most of the seconds on purpose.
  const seconds = document.createElement('p');
  seconds.className = 'fall-overlay__seconds';
  seconds.setAttribute('aria-hidden', 'true');
  const cancel = document.createElement('button');
  cancel.type = 'button';
  cancel.className = 'fall-overlay__cancel';
  cancel.addEventListener('click', onCancel);
  // A key held down since before the overlay opened must not dismiss an alert nobody has seen.
  cancel.addEventListener('keydown', (event) => {
    if (!ACTIVATION_KEYS.includes(event.key)) return;
    event.preventDefault();
    if (!event.repeat) onCancel();
  });
  root.append(title, seconds, cancel);

  // Outside the overlay: a live region must already be in the page, and visible to assistive
  // technology, before its text changes.
  const liveRegion = createLiveRegion();

  let active = false;

  const render = ({ deviceStatus }) => {
    const nextActive = deviceStatus.mode === 'fall-countdown';
    root.hidden = !nextActive;
    lock.set('fall', nextActive);

    if (nextActive && !active) {
      cancel.focus();
      // After the focus moves, since a focus change can cut off an announcement in progress.
      liveRegion.textContent = t('fall.announceStart', { seconds: config.countdownSeconds });
    } else if (!nextActive && active) {
      liveRegion.textContent = '';
      // In any other mode, the alert that took over has moved the focus itself.
      if (deviceStatus.mode === 'monitoring') returnFocusTo.focus();
    }
    active = nextActive;
  };
  const renderText = () => {
    title.textContent = t('fall.question');
    cancel.textContent = t('fall.cancel');
  };

  countdown.onTick((remaining) => {
    seconds.textContent = String(remaining);
    root.classList.toggle('fall-overlay--urgent', remaining <= config.urgentSeconds);
    if (remaining > 0) vibrate(VIBRATION_PER_SECOND);
    if (remaining > 0 && remaining <= config.urgentSeconds) {
      liveRegion.textContent = t('fall.announceRemaining', { seconds: remaining });
    }
  });
  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('deviceStatus')) render(state);
  });
  onLanguageChange(renderText);
  render(store.getState());
  renderText();

  return { root, liveRegion };
}
