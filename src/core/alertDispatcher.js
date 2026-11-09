import { criticalHeartRateConfig } from '../config/heartRateAnomaly.config.js';
import { buildAlertPayload } from './alertPayload.js';
import { createEventEmitter } from './eventEmitter.js';
import { ANOMALY_STATES, createHeartRateAnomalyDetector } from './heartRateAnomalyDetector.js';

const REASON_CRITICAL_HEART_RATE = 'high-heart-rate';

// A mock: it never touches the network. Sending an alert means recording it and telling the page,
// which is where a real integration with a messaging service would go.
export function createAlertDispatcher({
  store,
  sos,
  criticalDetector = createHeartRateAnomalyDetector({ config: criticalHeartRateConfig }),
  now = Date.now,
}) {
  const emitter = createEventEmitter();
  let alerts = [];

  const dispatch = (reason) => {
    const alert = buildAlertPayload({ state: store.getState(), reason, timestamp: now() });
    alerts.push(alert);
    emitter.emit('alert:dispatched', structuredClone(alert));
  };

  sos.on('sos:triggered', ({ reason }) => dispatch(reason));

  // A health alert, not a fall: nobody is asked anything, and the device mode stays as it is.
  criticalDetector.onWarning(() => {
    emitter.emit('heart-rate-critical', { timestamp: now() });
    dispatch(REASON_CRITICAL_HEART_RATE);
  });
  criticalDetector.onResolved(() => {
    emitter.emit('heart-rate-critical:resolved', { timestamp: now() });
  });

  store.subscribe(({ heartRate, accelerometer }) => {
    criticalDetector.process({ heartRate, accelerometer, timestamp: now() });
  });

  return {
    on: emitter.on,
    off: emitter.off,

    getAlerts: () => structuredClone(alerts),
    isCriticalActive: () => criticalDetector.getState() === ANOMALY_STATES.WARNING,

    reset() {
      alerts = [];
      criticalDetector.reset();
      emitter.emit('alerts:cleared');
    },
  };
}
