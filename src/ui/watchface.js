import { createBatteryIndicator } from './batteryIndicator.js';
import { createGpsIndicator } from './gpsIndicator.js';
import { createHeartRateIndicator } from './heartRateIndicator.js';
import { createSosButton } from './sosButton.js';
import { createWatchClock } from './watchClock.js';

function createZone(name) {
  const zone = document.createElement('div');
  zone.className = `watchface__${name}`;
  return zone;
}

export function createWatchface({ store }) {
  const root = document.createElement('div');
  root.className = 'watchface';

  const statusZone = createZone('status');
  const centerZone = createZone('center');
  const bottomZone = createZone('bottom');
  root.append(statusZone, centerZone, bottomZone);

  statusZone.append(createBatteryIndicator(store), createGpsIndicator(store));
  centerZone.append(createWatchClock(), createHeartRateIndicator(store));
  bottomZone.append(createSosButton());

  return root;
}
