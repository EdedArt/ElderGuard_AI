import { accelerometerMagnitude } from '../core/generators/accelerometer.js';
import { getLanguage, onLanguageChange, t } from '../i18n/index.js';

// Temporary live readout; Phase 3 replaces it with the real watchface.
export function createTelemetryReadout(store) {
  const root = document.createElement('div');
  root.className = 'telemetry-readout';

  const heartRate = document.createElement('p');
  heartRate.className = 'telemetry-readout__primary';
  const battery = document.createElement('p');
  const movement = document.createElement('p');
  root.append(heartRate, battery, movement);

  const render = (state) => {
    const magnitude = new Intl.NumberFormat(getLanguage(), {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(accelerometerMagnitude(state.accelerometer));

    heartRate.textContent = t('watch.readout.heartRate', { value: state.heartRate });
    battery.textContent = t('watch.readout.battery', { value: Math.round(state.battery.level) });
    movement.textContent = t('watch.readout.movement', { value: magnitude });
  };

  store.subscribe(render);
  onLanguageChange(() => render(store.getState()));
  render(store.getState());

  return root;
}
