import { createEventEmitter } from './eventEmitter.js';
import { createHeartRateAnomalyDetector } from './heartRateAnomalyDetector.js';

const HEALTH_ALERT_HIGH = 'high-heart-rate';

// Connects the anomaly detector to the telemetry stream. It only reports: it never touches the
// device mode, so it runs alongside the fall flow, whatever state that is in.
export function createHeartRateMonitor({
  store,
  detector = createHeartRateAnomalyDetector(),
  now = Date.now,
}) {
  const emitter = createEventEmitter();

  const setHealthAlert = (healthAlert) => store.update({ deviceStatus: { healthAlert } });

  detector.onWarning(() => {
    setHealthAlert(HEALTH_ALERT_HIGH);
    emitter.emit('heartRate:anomaly', {
      timestamp: now(),
      heartRate: store.getState().heartRate,
    });
  });

  detector.onResolved(() => {
    setHealthAlert(null);
    emitter.emit('heartRate:resolved', { timestamp: now() });
  });

  store.subscribe(({ heartRate, accelerometer }) => {
    detector.process({ heartRate, accelerometer, timestamp: now() });
  });

  return {
    on: emitter.on,
    off: emitter.off,
    getDetectorState: detector.getState,

    reset() {
      detector.reset();
      setHealthAlert(null);
    },
  };
}
