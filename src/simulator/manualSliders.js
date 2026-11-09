import { simulatorConfig } from '../config/simulator.config.js';
import { onLanguageChange, t } from '../i18n/index.js';

const { accelerometer: ACCELEROMETER_RANGE, heartRate: HEART_RATE_RANGE } = simulatorConfig.manual;

const formatBpm = (value) =>
  t('simulator.telemetry.bpmValue', { value, unit: t('watch.heartRate.unit') });
const formatG = (value) => t('simulator.telemetry.gValue', { value: value.toFixed(1) });

const CHANNELS = [
  {
    channel: 'heartRate',
    labelKey: 'simulator.telemetry.bpm',
    range: HEART_RATE_RANGE,
    read: ({ heartRate }) => heartRate,
    format: formatBpm,
  },
  ...['x', 'y', 'z'].map((axis) => ({
    channel: axis,
    labelKey: `simulator.telemetry.accel${axis.toUpperCase()}`,
    range: ACCELEROMETER_RANGE,
    read: ({ accelerometer }) => accelerometer[axis],
    format: formatG,
  })),
];

function createSliderRow({ channel, labelKey, range, read, format }, { store, controller, gate }) {
  const root = document.createElement('div');
  root.className = 'manual-slider';
  root.dataset.channel = channel;

  const sliderId = `manual-slider-${channel}`;
  const label = document.createElement('label');
  label.className = 'manual-slider__label';
  label.htmlFor = sliderId;
  const value = document.createElement('span');
  value.className = 'manual-slider__value';

  const slider = document.createElement('input');
  slider.type = 'range';
  slider.id = sliderId;
  slider.className = 'manual-slider__input';
  slider.min = String(range.min);
  slider.max = String(range.max);
  slider.step = String(range.step);

  const switchLabel = document.createElement('label');
  switchLabel.className = 'manual-slider__switch';
  const toggle = document.createElement('input');
  toggle.type = 'checkbox';
  toggle.setAttribute('role', 'switch');
  gate.add(toggle);
  const switchText = document.createElement('span');
  switchLabel.append(toggle, switchText);

  root.append(label, value, slider, switchLabel);

  const renderValue = () => {
    value.textContent = format(Number(slider.value));
  };

  // While on automatic, the slider follows the reading, so turning manual on causes no jump.
  const followReading = (state) => {
    if (controller.isManual(channel)) return;
    slider.value = String(read(state));
    renderValue();
  };

  const renderManual = () => {
    const isManual = controller.isManual(channel);
    toggle.checked = isManual;
    slider.disabled = !isManual;
    followReading(store.getState());
  };

  toggle.addEventListener('change', () => {
    if (toggle.checked) controller.setManual(channel, Number(slider.value));
    else controller.releaseManual(channel);
    renderManual();
  });
  slider.addEventListener('input', () => {
    if (controller.isManual(channel)) controller.setManual(channel, Number(slider.value));
    renderValue();
  });

  store.subscribe(followReading);
  controller.onManualChange(renderManual);

  const renderText = () => {
    label.textContent = t(labelKey);
    switchText.textContent = t('simulator.manual.switch');
    renderValue();
  };
  onLanguageChange(renderText);
  renderManual();
  renderText();

  return root;
}

export function createManualSliders({ store, controller, gate }) {
  const root = document.createElement('div');
  root.className = 'manual-sliders';
  root.append(...CHANNELS.map((channel) => createSliderRow(channel, { store, controller, gate })));
  return root;
}
