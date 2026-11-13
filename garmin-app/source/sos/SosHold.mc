import Toybox.Lang;

// Mirrors src/config/sos.config.js (SosConfig.kt in wear-app). Keep them in sync.
module SosConfig {
    // How long the "Mantén presionado" hint stays after a press that was too short.
    const HOLD_HINT_DURATION_MS = 2000;
}

// The state of the SOS control: whether it is pressed, and whether the "Mantén presionado" hint
// is showing. Times are milliseconds from System.getTimer(), passed in so tests control them.
//
// A press comes from holding the START button or holding a finger on the on-screen button.
// A simple tap or a short press never calls for help: it only shows the hint.
class SosHold {
    private var _pressedAt as Number or Null = null;
    private var _hintUntil as Number or Null = null;

    function initialize() {
    }

    // The button went down. A second press while already pressed is ignored.
    function press(now as Number) as Void {
        if (_pressedAt == null) {
            _pressedAt = now;
            _hintUntil = null;
        }
    }

    // The button went up: the press was too short, so the hint appears.
    function release(now as Number) as Void {
        if (_pressedAt != null) {
            _pressedAt = null;
            showHint(now);
        }
    }

    // A tap on the on-screen button: shows the hint, since a tap does nothing.
    function tap(now as Number) as Void {
        if (_pressedAt == null) {
            showHint(now);
        }
    }

    function isPressed() as Boolean {
        return _pressedAt != null;
    }

    function isHintVisible(now as Number) as Boolean {
        var until = _hintUntil;
        return until != null && now < until;
    }

    // True while something on screen depends on time, so the caller keeps redrawing.
    function isAnimating(now as Number) as Boolean {
        return isPressed() || isHintVisible(now);
    }

    private function showHint(now as Number) as Void {
        _hintUntil = now + SosConfig.HOLD_HINT_DURATION_MS;
    }
}
