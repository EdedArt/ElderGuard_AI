import { telemetryConfig } from '../config/telemetry.config.js';
import { createEventEmitter } from './eventEmitter.js';

function createInitialState({ heartRate, accelerometer, gps, battery }) {
  return {
    heartRate: Math.round((heartRate.restingMin + heartRate.restingMax) / 2),
    accelerometer: { ...accelerometer.rest },
    gps: { lat: gps.baseLat, lng: gps.baseLng, accuracy: gps.accuracyMin, signal: true },
    battery: { level: battery.startLevel, charging: false },
    deviceStatus: { mode: 'monitoring', lastUpdate: null },
  };
}

function isObject(value) {
  return value !== null && typeof value === 'object';
}

// Merges known keys only, so the state keeps its shape whatever a caller passes in.
function merge(target, partial) {
  const merged = { ...target };
  for (const key of Object.keys(partial)) {
    if (!Object.hasOwn(target, key)) continue;
    if (!isObject(target[key])) merged[key] = partial[key];
    else if (isObject(partial[key])) merged[key] = merge(target[key], partial[key]);
  }
  return merged;
}

function isSame(a, b) {
  if (!isObject(a) || !isObject(b)) return a === b;
  return Object.keys(a).every((key) => isSame(a[key], b[key]));
}

export function createTelemetryStore(config = telemetryConfig) {
  const emitter = createEventEmitter();
  let state = createInitialState(config);

  const replaceState = (next) => {
    const changedKeys = Object.keys(next).filter((key) => !isSame(state[key], next[key]));
    state = next;
    if (changedKeys.length > 0) emitter.emit('change', structuredClone(state), changedKeys);
  };

  return {
    getState: () => structuredClone(state),
    update: (partial) => replaceState(merge(state, structuredClone(partial))),
    subscribe: (listener) => emitter.on('change', listener),
    reset: () => replaceState(createInitialState(config)),
  };
}
