import { onLanguageChange, t } from '../i18n/index.js';
import { createBackgroundLock } from './backgroundLock.js';
import { createBatteryIndicator } from './batteryIndicator.js';
import { createGpsIndicator } from './gpsIndicator.js';
import { createHeartRateIndicator } from './heartRateIndicator.js';
import { createHoldHint } from './holdHint.js';
import { createSosAlternativeButton } from './sosAlternativeButton.js';
import { createSosButton } from './sosButton.js';
import { createSosConfirmScreen } from './sosConfirmScreen.js';
import { createSosScreen } from './sosScreen.js';
import { createStartScreen } from './startScreen.js';
import { createStatusAnnouncer } from './statusAnnouncer.js';
import { createWatchClock } from './watchClock.js';

function createZone(name) {
  const zone = document.createElement('div');
  zone.className = `watchface__${name}`;
  return zone;
}

export function createWatchface({ store, sos, onStart }) {
  const root = document.createElement('div');
  root.className = 'watchface';
  root.setAttribute('role', 'group');

  const statusZone = createZone('status');
  const centerZone = createZone('center');
  const bottomZone = createZone('bottom');
  const lock = createBackgroundLock([statusZone, centerZone, bottomZone]);

  const announcer = createStatusAnnouncer(store);
  const holdHint = createHoldHint({ announce: announcer.announce });
  const sosButton = createSosButton({
    onActivate: sos.trigger,
    onHoldStart: holdHint.hide,
    onShortPress: holdHint.show,
  });
  const sosConfirm = createSosConfirmScreen({
    store,
    lock,
    onConfirm: sos.trigger,
    returnFocusTo: () => sosAlternative,
  });
  const sosAlternative = createSosAlternativeButton({ onActivate: sosConfirm.open });

  statusZone.append(createBatteryIndicator(store), createGpsIndicator(store));
  centerZone.append(createWatchClock(), createHeartRateIndicator(store));
  bottomZone.append(sosButton, sosAlternative);

  const sosScreen = createSosScreen({
    store,
    onCancel: sos.cancel,
    lock,
    returnFocusTo: sosButton,
  });
  const startScreen = createStartScreen({ lock, onStart, returnFocusTo: sosButton });
  root.append(
    statusZone,
    centerZone,
    bottomZone,
    holdHint.root,
    sosConfirm.root,
    sosScreen,
    startScreen,
    announcer.root,
  );

  const renderLabel = () => root.setAttribute('aria-label', t('watch.face'));
  onLanguageChange(renderLabel);
  renderLabel();

  return root;
}
