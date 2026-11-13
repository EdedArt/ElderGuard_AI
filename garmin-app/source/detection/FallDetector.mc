import Toybox.Lang;

// Where the detector is in a fall: the 'idle' / 'impact' / 'immobility' / 'confirmed' states of
// the web app (FallState in wear-app).
enum FallState {
    FALL_IDLE,
    FALL_IMPACT,
    FALL_IMMOBILITY,
    FALL_CONFIRMED,
}

// Port of src/core/fallDetector.js (FallDetector.kt in wear-app). A fall is an impact followed by
// stillness. Either one alone happens in daily life: clapping or bumping the wrist makes a spike,
// and resting makes stillness. Time comes from the samples, so the detector needs no clock and
// every scenario can be replayed in a test.
//
//     idle ──impact──▶ impact ──still within the window──▶ immobility ──still long enough──▶ confirmed
//       ▲                 │ window passes                      │ movement
//       └─────────────────┴────────────────────────────────────┘
//
// A new impact in any state but confirmed restarts the sequence from that moment.
class FallDetector {
    private var _impactThresholdG as Double;
    private var _immobilityToleranceG as Double;
    private var _immobilityDurationMs as Number;
    private var _immobilityStartWindowMs as Number;

    private var _state as FallState = FALL_IDLE;
    private var _impactAt as Number = 0;
    private var _stillSince as Number = 0;

    // Every threshold is a parameter, so tests can use others; standard() uses FallDetectionConfig.
    function initialize(
        impactThresholdG as Double,
        immobilityToleranceG as Double,
        immobilityDurationMs as Number,
        immobilityStartWindowMs as Number
    ) {
        _impactThresholdG = impactThresholdG;
        _immobilityToleranceG = immobilityToleranceG;
        _immobilityDurationMs = immobilityDurationMs;
        _immobilityStartWindowMs = immobilityStartWindowMs;
    }

    // A detector with the thresholds of FallDetectionConfig, the ones the app uses.
    static function standard() as FallDetector {
        return new FallDetector(
            FallDetectionConfig.IMPACT_THRESHOLD_G,
            FallDetectionConfig.IMMOBILITY_TOLERANCE_G,
            FallDetectionConfig.IMMOBILITY_DURATION_MS,
            FallDetectionConfig.IMMOBILITY_START_WINDOW_MS
        );
    }

    function getState() as FallState {
        return _state;
    }

    // Takes one reading, taken at timestamp in milliseconds. Returns true when this reading
    // confirms a fall, which happens once: the detector then stays FALL_CONFIRMED and ignores
    // every reading until reset().
    function process(reading as Accelerometer, timestamp as Number) as Boolean {
        if (_state == FALL_CONFIRMED) {
            return false;
        }

        // Checked first in every state: a new blow restarts the sequence from that moment, so a
        // person who stumbles and then falls for real is still detected.
        if (reading.magnitude() >= _impactThresholdG) {
            _state = FALL_IMPACT;
            _impactAt = timestamp;
            return false;
        }

        var still = reading.isAtRest(_immobilityToleranceG);
        if (_state == FALL_IMPACT) {
            processAfterImpact(still, timestamp);
        } else if (_state == FALL_IMMOBILITY) {
            processImmobility(still, timestamp);
        }
        return _state == FALL_CONFIRMED;
    }

    // Forgets any sequence in progress, including a confirmed fall.
    function reset() as Void {
        _state = FALL_IDLE;
    }

    private function processAfterImpact(still as Boolean, timestamp as Number) as Void {
        if (timestamp - _impactAt > _immobilityStartWindowMs) {
            _state = FALL_IDLE;
        } else if (still) {
            _state = FALL_IMMOBILITY;
            _stillSince = timestamp;
        }
    }

    private function processImmobility(still as Boolean, timestamp as Number) as Void {
        if (!still) {
            _state = FALL_IDLE;
        } else if (timestamp - _stillSince >= _immobilityDurationMs) {
            _state = FALL_CONFIRMED;
        }
    }
}
