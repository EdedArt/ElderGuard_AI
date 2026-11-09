import { heartRateAnomalyConfig } from '../config/heartRateAnomaly.config.js';
import { createEventEmitter } from './eventEmitter.js';
import { isAtRest } from './magnitude.js';

export const ANOMALY_STATES = Object.freeze({
  NORMAL: 'normal',
  ELEVATED: 'elevated',
  WARNING: 'warning',
});

// A fast heart is expected while moving and harmless for a moment, so only one that stays fast at
// rest counts. Time comes from the samples, so every case can be replayed in a test.
export function createHeartRateAnomalyDetector({ config = heartRateAnomalyConfig } = {}) {
  const emitter = createEventEmitter();
  let state = ANOMALY_STATES.NORMAL;
  let elevatedSince = null;

  return {
    process({ heartRate, accelerometer, timestamp }) {
      const elevated = heartRate > config.bpmThreshold;
      if (!elevated || !isAtRest(accelerometer, config.stillnessToleranceG)) {
        const wasWarning = state === ANOMALY_STATES.WARNING;
        state = ANOMALY_STATES.NORMAL;
        if (wasWarning) emitter.emit('resolved');
        return;
      }

      if (state === ANOMALY_STATES.NORMAL) {
        state = ANOMALY_STATES.ELEVATED;
        elevatedSince = timestamp;
      }
      if (
        state === ANOMALY_STATES.ELEVATED &&
        timestamp - elevatedSince >= config.sustainedDurationMs
      ) {
        state = ANOMALY_STATES.WARNING;
        emitter.emit('warning');
      }
    },

    getState: () => state,

    // Starts over without reporting anything: whoever resets knows the warning is gone.
    reset() {
      state = ANOMALY_STATES.NORMAL;
    },

    onWarning: (listener) => emitter.on('warning', listener),
    onResolved: (listener) => emitter.on('resolved', listener),
  };
}
