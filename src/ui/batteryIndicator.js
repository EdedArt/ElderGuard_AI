import { batteryPercent, batteryState } from '../core/watchStatus.js';
import { onLanguageChange, t } from '../i18n/index.js';

const FILL_MAX_WIDTH = 20;
const BATTERY_ICON = `
  <svg viewBox="0 0 28 14" aria-hidden="true" focusable="false">
    <rect x="1" y="1" width="23" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="2" />
    <rect x="25" y="4.500" width="3" height="5" rx="1" fill="currentColor" />
    <rect class="battery-indicator__fill" x="2.500" y="2.500" height="9" fill="currentColor" />
  </svg>
`;

export function createBatteryIndicator(store) {
  const root = document.createElement('div');
  root.className = 'battery-indicator';
  root.setAttribute('role', 'img');

  const icon = document.createElement('span');
  icon.className = 'battery-indicator__icon';
  icon.innerHTML = BATTERY_ICON;
  const fill = icon.querySelector('.battery-indicator__fill');

  const value = document.createElement('span');
  value.className = 'battery-indicator__value';
  root.append(icon, value);

  const render = ({ battery }) => {
    // The state follows the rounded value, so "20 %" never looks normal.
    const percent = batteryPercent(battery.level);
    root.dataset.state = batteryState(percent);
    fill.setAttribute('width', String((FILL_MAX_WIDTH * percent) / 100));
    value.textContent = t('watch.battery.value', { value: percent });
    root.setAttribute('aria-label', t('watch.battery.label', { value: percent }));
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('battery')) render(state);
  });
  onLanguageChange(() => render(store.getState()));
  render(store.getState());

  return root;
}
