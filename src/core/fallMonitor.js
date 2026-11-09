import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { createEventEmitter } from './eventEmitter.js';
import { createFallDetector } from './fallDetector.js';

const MODE_MONITORING = 'monitoring';
const MODE_FALL_COUNTDOWN = 'fall-countdown';

// Connects the detector to the telemetry stream and runs the alert that follows a detection.
export function createFallMonitor({
  store,
  sos,
  countdown,
  detector = createFallDetector(),
  config = fallDetectionConfig,
  now = Date.now,
}) {
  const emitter = createEventEmitter();
  let previousMode = store.getState().deviceStatus.mode;

  detector.onConfirmed(() => {
    store.update({ deviceStatus: { mode: MODE_FALL_COUNTDOWN } });
    emitter.emit('fall:detected', { timestamp: now(), gps: store.getState().gps });
    countdown.start(config.countdownSeconds);
  });

  countdown.onComplete(() => sos.trigger({ reason: 'fall' }));

  // Every change counts as a sample, not only those listing the accelerometer: the store leaves
  // an unchanged reading out of its changed keys, and a body lying perfectly still gives exactly
  // that. The detector needs those samples to see the time go by.
  store.subscribe(({ accelerometer, deviceStatus: { mode } }) => {
    const wasMonitoring = previousMode === MODE_MONITORING;
    previousMode = mode;

    if (mode !== MODE_FALL_COUNTDOWN) countdown.cancel();

    if (mode !== MODE_MONITORING) {
      // Otherwise a fall in progress would resume, with a gap in its timing, after the alert ends.
      detector.reset();
    } else if (wasMonitoring) {
      // Coming back from an alert is no sample: the reading still dates from during the alert.
      detector.process({ accelerometer, timestamp: now() });
    }
  });

  return {
    on: emitter.on,
    off: emitter.off,

    cancel() {
      if (store.getState().deviceStatus.mode !== MODE_FALL_COUNTDOWN) return;
      countdown.cancel();
      detector.reset();
      store.update({ deviceStatus: { mode: MODE_MONITORING } });
      emitter.emit('fall:cancelled', { timestamp: now() });
    },
  };
}
