import { onLanguageChange, t } from '../i18n/index.js';
import { createActionButton } from './actionButton.js';
import { createAlertHistory } from './alertHistory.js';
import { createDemoController } from './demoController.js';
import { createEventLog } from './eventLog.js';
import { createFallStateIndicator } from './fallStateIndicator.js';
import { createManualSliders } from './manualSliders.js';
import { createPanelSection } from './panelSection.js';
import { createShortcutHelp, installPresenterShortcuts } from './shortcuts.js';
import { createStartGate } from './startGate.js';
import { createTelemetryReadout } from './telemetryReadout.js';

const COLLAPSED_STORAGE_KEY = 'elderguard.simulator.collapsed';
const PANEL_TITLE_ID = 'simulator-panel-title';
const PANEL_BODY_ID = 'simulator-panel-body';

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

export function createSimulatorPanel({ device, shortcutTarget = document }) {
  const panel = document.createElement('aside');
  panel.className = 'simulator-panel';

  const header = document.createElement('header');
  header.className = 'simulator-panel__header';
  const heading = document.createElement('h2');
  heading.className = 'simulator-panel__title';
  heading.id = PANEL_TITLE_ID;
  panel.setAttribute('aria-labelledby', PANEL_TITLE_ID);
  const collapse = document.createElement('button');
  collapse.type = 'button';
  collapse.className = 'simulator-panel__collapse';
  const shortcutHelp = createShortcutHelp();
  const headerActions = document.createElement('div');
  headerActions.className = 'simulator-panel__header-actions';
  headerActions.append(shortcutHelp.toggle, collapse);
  header.append(heading, headerActions);

  const body = document.createElement('div');
  body.className = 'simulator-panel__body';
  body.id = PANEL_BODY_ID;
  collapse.setAttribute('aria-controls', PANEL_BODY_ID);
  const hint = document.createElement('p');
  hint.className = 'simulator-panel__hint';

  const gate = createStartGate(device);
  hint.hidden = gate.isOpen();
  gate.onOpen(() => {
    hint.hidden = true;
  });
  const controller = createDemoController({ device });
  const action = (name, onClick) =>
    createActionButton({ action: name, labelKey: `simulator.actions.${name}`, onClick, gate })
      .button;
  const scenarioAction = (id) => action(id, () => controller.runScenario(id));

  const gpsToggle = createActionButton({
    action: 'gpsToggle',
    labelKey: () =>
      device.store.getState().gps.signal
        ? 'simulator.actions.gpsLose'
        : 'simulator.actions.gpsRestore',
    onClick: controller.toggleGps,
    gate,
  });
  device.store.subscribe((state, changedKeys) => {
    if (changedKeys.includes('gps')) gpsToggle.render();
  });

  const scenarioControls = createPanelSection('simulator.sections.scenarios', { controls: true });
  scenarioControls.content.append(
    scenarioAction('fall'),
    scenarioAction('stumble'),
    scenarioAction('highHeartRate'),
    scenarioAction('criticalHeartRate'),
    scenarioAction('lowBattery'),
    scenarioAction('criticalBattery'),
    action('restoreBattery', controller.restoreBattery),
    gpsToggle.button,
  );

  const manualControls = createPanelSection('simulator.sections.manual', { controls: true });
  manualControls.content.append(createManualSliders({ store: device.store, controller, gate }));

  const status = createPanelSection('simulator.sections.status');
  const fallState = createFallStateIndicator(device);
  status.content.append(fallState.root, createTelemetryReadout(device.store));
  // A reset right after starting may change nothing in the store, but it does change the detector.
  controller.onReset(fallState.render);

  // Closing an alert sends the focus back to the watch, away from where the presenter is working.
  const reset = action('reset', () => {
    controller.resetAll();
    reset.focus();
  });
  reset.classList.add('simulator-action--reset');
  scenarioControls.content.append(reset);
  const alertHistory = createPanelSection('simulator.sections.alerts');
  alertHistory.content.append(createAlertHistory(device));

  const log = createPanelSection('simulator.sections.log');
  log.content.append(createEventLog({ device, controller }));

  // The state stays right below the scenarios, so it is on screen while the audience watches them.
  body.append(
    hint,
    scenarioControls.root,
    status.root,
    alertHistory.root,
    manualControls.root,
    log.root,
  );

  // Outside the body, since the shortcuts also work with the panel collapsed.
  panel.append(header, shortcutHelp.list, body);

  installPresenterShortcuts({ controller, gate, target: shortcutTarget });

  let collapsed = loadCollapsed();

  const renderCollapse = () => {
    body.hidden = collapsed;
    collapse.setAttribute('aria-expanded', String(!collapsed));
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
