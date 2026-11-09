import { onLanguageChange, t } from '../i18n/index.js';

const LIST_ID = 'simulator-shortcuts-list';

const SHORTCUTS = [
  {
    key: '1',
    labelKey: 'simulator.actions.fall',
    run: (controller) => controller.runScenario('fall'),
  },
  {
    key: '2',
    labelKey: 'simulator.actions.stumble',
    run: (controller) => controller.runScenario('stumble'),
  },
  {
    key: '3',
    labelKey: 'simulator.actions.highHeartRate',
    run: (controller) => controller.runScenario('highHeartRate'),
  },
  {
    key: '4',
    labelKey: 'simulator.actions.lowBattery',
    run: (controller) => controller.runScenario('lowBattery'),
  },
  {
    key: '5',
    labelKey: 'simulator.shortcuts.gps',
    run: (controller) => controller.toggleGps(),
  },
  {
    key: '0',
    labelKey: 'simulator.actions.reset',
    run: (controller) => controller.resetAll(),
  },
];

// Sliders and switches stay out of this: nothing is typed into them, and shortcuts would otherwise
// stop working as soon as the presenter touches one.
const NON_TEXT_INPUTS = [
  'range',
  'checkbox',
  'radio',
  'button',
  'submit',
  'reset',
  'color',
  'file',
];

function isTyping(element) {
  if (element?.isContentEditable) return true;
  if (element?.tagName === 'TEXTAREA' || element?.tagName === 'SELECT') return true;
  return element?.tagName === 'INPUT' && !NON_TEXT_INPUTS.includes(element.type);
}

// By physical key where available, since Alt can change the character a key produces.
function pressedDigit(event) {
  return /^Digit(\d)$/.exec(event.code ?? '')?.[1] ?? event.key;
}

export function installPresenterShortcuts({ controller, gate, target = document }) {
  target.addEventListener('keydown', (event) => {
    // AltGr, needed for symbols on Spanish keyboards, reports as Ctrl+Alt on Windows.
    if (!event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    const digit = pressedDigit(event);
    const shortcut = SHORTCUTS.find(({ key }) => key === digit);
    if (!shortcut || isTyping(event.target)) return;

    event.preventDefault();
    if (gate.isOpen() && !event.repeat) shortcut.run(controller);
  });
}

export function createShortcutHelp() {
  const toggle = document.createElement('button');
  toggle.type = 'button';
  toggle.className = 'simulator-panel__help';

  const list = document.createElement('dl');
  list.id = LIST_ID;
  list.className = 'shortcut-list';
  list.hidden = true;

  const rows = SHORTCUTS.map(({ key, labelKey }) => {
    const row = document.createElement('div');
    row.className = 'shortcut-list__row';
    const combo = document.createElement('dt');
    const label = document.createElement('dd');
    row.append(combo, label);
    list.append(row);
    return { key, labelKey, combo, label };
  });

  toggle.addEventListener('click', () => {
    list.hidden = !list.hidden;
  });

  const render = () => {
    toggle.textContent = t('simulator.shortcuts.toggle');
    toggle.setAttribute('aria-label', t('simulator.shortcuts.toggleLabel'));
    for (const { key, labelKey, combo, label } of rows) {
      combo.textContent = t('simulator.shortcuts.combo', { key });
      label.textContent = t(labelKey);
    }
  };
  onLanguageChange(render);
  render();

  return { toggle, list };
}
