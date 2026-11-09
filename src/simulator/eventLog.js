import { simulatorConfig } from '../config/simulator.config.js';
import { batteryPercent, batteryState, gpsState } from '../core/watchStatus.js';
import { getLanguage, onLanguageChange, t } from '../i18n/index.js';

const scenarioName = (scenario) => t(`simulator.scenarios.${scenario.id}`);

function formatTime(timestamp) {
  return new Date(timestamp).toLocaleTimeString(getLanguage(), {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });
}

// Entries keep what to say, not the text, so they follow the language too.
export function createEventLog({
  device,
  controller,
  now = Date.now,
  maxEntries = simulatorConfig.logMaxEntries,
}) {
  const root = document.createElement('div');
  root.className = 'event-log';

  const clear = document.createElement('button');
  clear.type = 'button';
  clear.className = 'simulator-action event-log__clear';
  const empty = document.createElement('p');
  empty.className = 'event-log__empty';
  const list = document.createElement('ol');
  list.className = 'event-log__list';
  // Only new entries are read out, not old ones dropping off or a change of language.
  list.setAttribute('role', 'log');
  list.setAttribute('aria-live', 'polite');
  list.setAttribute('aria-relevant', 'additions');
  // The list scrolls, which a keyboard user can only do once it can take the focus.
  list.tabIndex = 0;
  root.append(clear, empty, list);

  let entries = [];

  const renderEntry = ({ timestamp, describe, time, message }) => {
    time.textContent = formatTime(timestamp);
    message.textContent = describe();
  };

  const add = (describe) => {
    const item = document.createElement('li');
    item.className = 'event-log__entry';
    const time = document.createElement('time');
    time.className = 'event-log__time';
    const message = document.createElement('span');
    item.append(time, message);

    const entry = { timestamp: now(), describe, item, time, message };
    renderEntry(entry);
    list.prepend(item);
    entries.unshift(entry);
    if (entries.length > maxEntries) entries.pop().item.remove();
    empty.hidden = true;
  };

  clear.addEventListener('click', () => {
    entries = [];
    list.replaceChildren();
    empty.hidden = false;
  });

  const { fall, scenarioRunner, sos, store } = device;

  scenarioRunner.onStart(({ scenario }) => {
    const key = scenario.holds
      ? 'simulator.log.scenarioActivated'
      : 'simulator.log.scenarioStarted';
    add(() => t(key, { name: scenarioName(scenario) }));
  });
  scenarioRunner.onEnd(({ scenario, completed }) => {
    // Having applied its steps, a held scenario is not over: it is logged when actually cleared.
    if (scenario.holds && completed) return;
    const key = completed ? 'simulator.log.scenarioFinished' : 'simulator.log.scenarioStopped';
    add(() => t(key, { name: scenarioName(scenario) }));
  });
  fall.on('fall:detected', () => add(() => t('simulator.log.fallDetected')));
  fall.on('fall:cancelled', () => add(() => t('simulator.log.fallCancelled')));
  sos.on('sos:triggered', ({ reason }) =>
    add(() => t('simulator.log.sosTriggered', { reason: t(`simulator.log.sosReason.${reason}`) })),
  );
  sos.on('sos:cancelled', () => add(() => t('simulator.log.sosCancelled')));
  controller.onScenarioRestored(({ scenario }) =>
    add(() => t('simulator.log.scenarioRestored', { name: scenarioName(scenario) })),
  );
  controller.onReset(() => add(() => t('simulator.log.reset')));

  const initial = store.getState();
  let previousBattery = batteryState(batteryPercent(initial.battery.level));
  let previousGps = gpsState(initial.gps);

  store.subscribe((state) => {
    const level = batteryPercent(state.battery.level);
    const battery = batteryState(level);
    if (battery !== previousBattery) {
      previousBattery = battery;
      add(() => t(`simulator.log.battery.${battery}`, { level }));
    }

    const gps = gpsState(state.gps);
    if (gps !== previousGps) {
      previousGps = gps;
      add(() => t(`simulator.log.gps.${gps}`));
    }
  });

  const render = () => {
    list.setAttribute('aria-label', t('simulator.sections.log'));
    clear.textContent = t('simulator.log.clear');
    empty.textContent = t('simulator.log.empty');
    entries.forEach(renderEntry);
  };
  onLanguageChange(render);
  render();

  return root;
}
