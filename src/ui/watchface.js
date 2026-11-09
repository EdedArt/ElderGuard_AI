import { createWatchClock } from './watchClock.js';

function createZone(name) {
  const zone = document.createElement('div');
  zone.className = `watchface__${name}`;
  return zone;
}

export function createWatchface() {
  const root = document.createElement('div');
  root.className = 'watchface';

  const statusZone = createZone('status');
  const centerZone = createZone('center');
  const bottomZone = createZone('bottom');
  root.append(statusZone, centerZone, bottomZone);

  centerZone.append(createWatchClock());

  return root;
}
