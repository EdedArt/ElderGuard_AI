import { heartbeatIntervalMs } from '../core/watchStatus.js';
import { onLanguageChange, t } from '../i18n/index.js';

const HEART_ICON = `
  <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
    <path fill="currentColor" d="M12 21S3 15.400 3 8.800C3 5.900 5.200 4 7.700 4c1.800 0 3.400 1 4.300 2.500C12.900 5 14.500 4 16.300 4 18.800 4 21 5.900 21 8.800 21 15.400 12 21 12 21Z" />
  </svg>
`;

export function createHeartRateIndicator(store) {
  const root = document.createElement('div');
  root.className = 'heart-rate';

  const icon = document.createElement('span');
  icon.className = 'heart-rate__icon';
  icon.innerHTML = HEART_ICON;

  const value = document.createElement('span');
  value.className = 'heart-rate__value';
  const unit = document.createElement('span');
  unit.className = 'heart-rate__unit';
  root.append(icon, value, unit);

  const renderValue = (bpm) => {
    value.textContent = String(bpm);
    root.style.setProperty('--heartbeat-interval', `${heartbeatIntervalMs(bpm)}ms`);
  };
  const renderText = () => {
    unit.textContent = t('watch.heartRate.unit');
  };

  store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('heartRate')) renderValue(state.heartRate);
  });
  onLanguageChange(renderText);
  renderValue(store.getState().heartRate);
  renderText();

  return root;
}
