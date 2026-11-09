import { onLanguageChange, t } from '../i18n/index.js';

// Shows the real detector state, so the audience can watch the algorithm work during the demo.
export function createFallStateIndicator({ store, fall }) {
  const root = document.createElement('div');
  root.className = 'fall-state';

  const label = document.createElement('span');
  label.className = 'fall-state__label';
  const value = document.createElement('span');
  value.className = 'fall-state__value';
  root.append(label, value);

  const render = () => {
    const state = fall.getDetectorState();
    root.dataset.state = state;
    label.textContent = t('simulator.fallState.label');
    value.textContent = t(`simulator.fallState.${state}`);
  };

  // The monitor subscribed to the store first, so the detector has seen each change by now.
  store.subscribe(render);
  onLanguageChange(render);
  render();

  return { root, render };
}
