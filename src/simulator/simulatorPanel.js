import { onLanguageChange, t } from '../i18n/index.js';
import { createFallStateIndicator } from './fallStateIndicator.js';
import { createPanelSection } from './panelSection.js';
import { createStartGate } from './startGate.js';
import { createTelemetryReadout } from './telemetryReadout.js';

const COLLAPSED_STORAGE_KEY = 'elderguard.simulator.collapsed';

function loadCollapsed() {
  try {
    return localStorage.getItem(COLLAPSED_STORAGE_KEY) === 'true';
  } catch {
    return false;
  }
}

function saveCollapsed(collapsed) {
  try {
    localStorage.setItem(COLLAPSED_STORAGE_KEY, String(collapsed));
  } catch {
    // Storage can be unavailable; the choice then only lasts until reload.
  }
}

export function createSimulatorPanel({ device }) {
  const panel = document.createElement('aside');
  panel.className = 'simulator-panel';

  const header = document.createElement('header');
  header.className = 'simulator-panel__header';
  const heading = document.createElement('h2');
  heading.className = 'simulator-panel__title';
  const collapse = document.createElement('button');
  collapse.type = 'button';
  collapse.className = 'simulator-panel__collapse';
  header.append(heading, collapse);

  const body = document.createElement('div');
  body.className = 'simulator-panel__body';
  const hint = document.createElement('p');
  hint.className = 'simulator-panel__hint';

  const gate = createStartGate(device);
  hint.hidden = gate.isOpen();
  gate.onOpen(() => {
    hint.hidden = true;
  });
  const status = createPanelSection('simulator.sections.status');
  const fallState = createFallStateIndicator(device);
  status.content.append(fallState.root, createTelemetryReadout(device.store));
  body.append(hint, status.root);

  panel.append(header, body);

  let collapsed = loadCollapsed();

  const renderCollapse = () => {
    body.hidden = collapsed;
    collapse.textContent = t(collapsed ? 'simulator.expand' : 'simulator.collapse');
  };
  collapse.addEventListener('click', () => {
    collapsed = !collapsed;
    saveCollapsed(collapsed);
    renderCollapse();
  });

  const render = () => {
    heading.textContent = t('simulator.title');
    hint.textContent = t('simulator.startFirst');
    renderCollapse();
  };
  onLanguageChange(render);
  render();

  return panel;
}
