import { magnitude } from '../core/magnitude.js';
import { batteryPercent } from '../core/watchStatus.js';
import { onLanguageChange, t } from '../i18n/index.js';

const G_DECIMALS = 2;
const COORDINATE_DECIMALS = 5;

const formatG = (value) => t('simulator.telemetry.gValue', { value: value.toFixed(G_DECIMALS) });

// Each row maps a label to how its value reads from the telemetry state.
const ROWS = [
  [
    'bpm',
    ({ heartRate }) =>
      t('simulator.telemetry.bpmValue', { value: heartRate, unit: t('watch.heartRate.unit') }),
  ],
  ['accelX', ({ accelerometer }) => formatG(accelerometer.x)],
  ['accelY', ({ accelerometer }) => formatG(accelerometer.y)],
  ['accelZ', ({ accelerometer }) => formatG(accelerometer.z)],
  ['magnitude', ({ accelerometer }) => formatG(magnitude(accelerometer))],
  ['lat', ({ gps }) => gps.lat.toFixed(COORDINATE_DECIMALS)],
  ['lng', ({ gps }) => gps.lng.toFixed(COORDINATE_DECIMALS)],
  [
    'signal',
    ({ gps }) => t(gps.signal ? 'simulator.telemetry.signalOk' : 'simulator.telemetry.signalLost'),
  ],
  ['battery', ({ battery }) => t('watch.battery.value', { value: batteryPercent(battery.level) })],
  ['mode', ({ deviceStatus }) => t(`simulator.mode.${deviceStatus.mode}`)],
];

export function createTelemetryReadout(store) {
  const root = document.createElement('dl');
  root.className = 'telemetry-readout';

  const rows = ROWS.map(([name, read]) => {
    const row = document.createElement('div');
    row.className = 'telemetry-readout__row';
    const label = document.createElement('dt');
    const value = document.createElement('dd');
    value.dataset.telemetry = name;
    row.append(label, value);
    root.append(row);
    return { name, read, label, value };
  });

  const renderValues = (state) => {
    for (const { read, value } of rows) value.textContent = read(state);
  };
  const render = () => {
    for (const { name, label } of rows) label.textContent = t(`simulator.telemetry.${name}`);
    renderValues(store.getState());
  };

  store.subscribe(renderValues);
  onLanguageChange(render);
  render();

  return root;
}
