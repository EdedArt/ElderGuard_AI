import { createBatteryIndicator } from './batteryIndicator.js';
import { createGpsIndicator } from './gpsIndicator.js';
import { createHeartRateIndicator } from './heartRateIndicator.js';
import { createSosButton } from './sosButton.js';
import { createSosScreen } from './sosScreen.js';
import { createWatchClock } from './watchClock.js';

function createZone(name) {
  const zone = document.createElement('div');
  zone.className = `watchface__${name}`;
  return zone;
}

export function createWatchface({ store, sos }) {
  const root = document.createElement('div');
  root.className = 'watchface';

  const statusZone = createZone('status');
  const centerZone = createZone('center');
  const bottomZone = createZone('bottom');

  const sosButton = createSosButton({ onActivate: sos.trigger });
  statusZone.append(createBatteryIndicator(store), createGpsIndicator(store));
  centerZone.append(createWatchClock(), createHeartRateIndicator(store));
  bottomZone.append(sosButton);

  const sosScreen = createSosScreen({
    store,
    onCancel: sos.cancel,
    background: [statusZone, centerZone, bottomZone],
    returnFocusTo: sosButton,
  });
  root.append(statusZone, centerZone, bottomZone, sosScreen);

  return root;
}
