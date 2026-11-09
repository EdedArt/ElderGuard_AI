import { createEventEmitter } from './eventEmitter.js';
import { createFallDetector } from './fallDetector.js';

const MODE_MONITORING = 'monitoring';
const MODE_FALL_COUNTDOWN = 'fall-countdown';

// Connects the detector to the telemetry stream and tells the rest of the app about falls.
export function createFallMonitor({ store, detector = createFallDetector(), now = Date.now }) {
  const emitter = createEventEmitter();

  detector.onConfirmed(() => {
    store.update({ deviceStatus: { mode: MODE_FALL_COUNTDOWN } });
    emitter.emit('fall:detected', { timestamp: now(), gps: store.getState().gps });
  });

  // Every change counts as a sample, not only those listing the accelerometer: the store leaves
  // an unchanged reading out of its changed keys, and a body lying perfectly still gives exactly
  // that. The detector needs those samples to see the time go by.
  store.subscribe(({ accelerometer, deviceStatus }) => {
    if (deviceStatus.mode === MODE_MONITORING) {
      detector.process({ accelerometer, timestamp: now() });
    } else {
      // Otherwise a fall in progress would resume, with a gap in its timing, after the alert ends.
      detector.reset();
    }
  });

  return {
    on: emitter.on,
    off: emitter.off,
  };
}
