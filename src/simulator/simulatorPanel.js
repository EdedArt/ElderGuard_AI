import { onLanguageChange, t } from '../i18n/index.js';

export function createSimulatorPanel() {
  const panel = document.createElement('aside');
  panel.className = 'simulator-panel';

  const heading = document.createElement('h2');
  panel.append(heading);

  const render = () => {
    heading.textContent = t('simulator.title');
  };
  onLanguageChange(render);
  render();

  return panel;
}
