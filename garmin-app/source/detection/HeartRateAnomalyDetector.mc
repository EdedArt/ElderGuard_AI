import Toybox.Lang;

// The 'normal' / 'elevated' / 'warning' states of the web app's detector (AnomalyState in wear-app).
enum AnomalyState {
    ANOMALY_NORMAL,
    ANOMALY_ELEVATED,
    ANOMALY_WARNING,
}

// What a reading changed: the web app's 'warning' and 'resolved' events.
enum AnomalyEvent {
    ANOMALY_EVENT_WARNING,
    ANOMALY_EVENT_RESOLVED,
}

// Port of src/core/heartRateAnomalyDetector.js (HeartRateAnomalyDetector.kt in wear-app). A fast
// heart is expected while moving and harmless for a moment, so only one that stays fast at rest
// counts. Time comes from the samples, so every case can be replayed in a test.
//
//     normal ──high at rest──▶ elevated ──for the sustained time──▶ warning
//        ▲                         │                                   │
//        └── not high, or moving ──┴───────────────────────────────────┘ (resolved)
class HeartRateAnomalyDetector {
    private var _bpmThreshold as Number;
    private var _sustainedDurationMs as Number;
    private var _stillnessToleranceG as Double;

    private var _state as AnomalyState = ANOMALY_NORMAL;
    private var _elevatedSince as Number = 0;

    function initialize(bpmThreshold as Number, sustainedDurationMs as Number, stillnessToleranceG as Double) {
        _bpmThreshold = bpmThreshold;
        _sustainedDurationMs = sustainedDurationMs;
        _stillnessToleranceG = stillnessToleranceG;
    }

    // The warning level of HeartRateAnomalyConfig: shows the banner.
    static function warning() as HeartRateAnomalyDetector {
        return new HeartRateAnomalyDetector(HeartRateAnomalyConfig.BPM_THRESHOLD,
            HeartRateAnomalyConfig.SUSTAINED_DURATION_MS, HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G);
    }

    // The critical level: tells the family.
    static function critical() as HeartRateAnomalyDetector {
        return new HeartRateAnomalyDetector(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD,
            HeartRateAnomalyConfig.SUSTAINED_DURATION_MS, HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G);
    }

    function getState() as AnomalyState {
        return _state;
    }

    // Takes one reading, taken at timestamp in milliseconds. Returns ANOMALY_EVENT_WARNING when
    // this reading completes the sustained time, ANOMALY_EVENT_RESOLVED when it ends a warning,
    // and null otherwise. The state is already updated when it returns.
    function process(bpm as Number, reading as Accelerometer, timestamp as Number) as AnomalyEvent or Null {
        if (bpm <= _bpmThreshold || !reading.isAtRest(_stillnessToleranceG)) {
            var wasWarning = _state == ANOMALY_WARNING;
            _state = ANOMALY_NORMAL;
            return wasWarning ? ANOMALY_EVENT_RESOLVED : null;
        }
        if (_state == ANOMALY_NORMAL) {
            _state = ANOMALY_ELEVATED;
            _elevatedSince = timestamp;
        }
        if (_state == ANOMALY_ELEVATED && timestamp - _elevatedSince >= _sustainedDurationMs) {
            _state = ANOMALY_WARNING;
            return ANOMALY_EVENT_WARNING;
        }
        return null;
    }

    // Starts over without reporting anything: whoever resets knows the warning is gone.
    function reset() as Void {
        _state = ANOMALY_NORMAL;
    }
}
