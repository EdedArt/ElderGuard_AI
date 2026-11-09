import { gpsState } from '../core/watchStatus.js';
import { onLanguageChange, t } from '../i18n/index.js';

const GPS_ICON = `
  <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
    <path fill="currentColor" fill-rule="evenodd" d="M12 2a7.500 7.500 0 0 0-7.500 7.500C4.500 15 12 22 12 22s7.500-7 7.500-12.500A7.500 7.500 0 0 0 12 2Zm0 10.500a3 3 0 1 1 0-6 3 3 0 0 1 0 6Z" />
    <line class="gps-indicator__slash" x1="3" y1="3" x2="21" y2="21" stroke="currentColor" stroke-width="2.500" stroke-linecap="round" />
  </svg>
`;

export function createGpsIndicator(store) {
  const root = document.createElement('div');
  root.className = 'gps-indicator';

  const icon = document.createElement('span');
  icon.className = 'gps-indicator__icon';
  icon.innerHTML = GPS_ICON;

  const label = document.createElement('span');
  label.className = 'gps-indicator__label';
  root.append(icon, label);

  const render = ({ gps }) => {
    const state = gpsState(gps);
    root.dataset.state = state;
    label.textContent = t(`watch.gps.${state}`);
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('gps')) render(state);
  });
  onLanguageChange(() => render(store.getState()));
  render(store.getState());

  return root;
}
