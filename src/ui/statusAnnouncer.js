import { statusChanges } from '../core/watchStatus.js';
import { t } from '../i18n/index.js';

// Screen reader announcements for status changes only, so readings never interrupt the user.
export function createStatusAnnouncer(store) {
  const root = document.createElement('div');
  root.className = 'visually-hidden';
  root.setAttribute('role', 'status');
  root.setAttribute('aria-live', 'polite');

  let previous = store.getState();

  store.subscribe((state) => {
    const changes = statusChanges(previous, state);
    previous = state;
    if (changes.length > 0) {
      root.textContent = changes.map((change) => t(`watch.status.${change}`)).join('. ');
    }
  });

  return root;
}
