import Toybox.Lang;

// Mirrors src/config/sos.config.js (SosConfig.kt in wear-app). Keep them in sync.
module SosConfig {
    // How long the SOS button must be held to call for help.
    const HOLD_DURATION_MS = 2000;

    // How long the "Mantén presionado" hint stays after a press that was too short.
    const HOLD_HINT_DURATION_MS = 2000;
}

// The state of the SOS control: whether it is pressed, how far the hold has gone, and whether the
// "Mantén presionado" hint is showing. Times are milliseconds from System.getTimer(), passed in so
// tests control them.
//
// A press comes from holding the START button or holding a finger on the on-screen button. Only a
// hold of SosConfig.HOLD_DURATION_MS completes it, without waiting for the release; a tap or a
// shorter press never calls for help and shows the hint instead. Port of the hold logic in
// src/core/longPress.js.
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

    // The button went up. If the hold had not completed, it was too short: the hint appears.
    // After a completed hold the press is already over, so its release changes nothing.
    function release(now as Number) as Void {
        if (_pressedAt != null) {
            _pressedAt = null;
            showHint(now);
        }
    }

    // How far the current hold has gone, from 0 (not pressed) to 1 (complete).
    function progress(now as Number) as Float {
        var pressedAt = _pressedAt;
        if (pressedAt == null) {
            return 0.0;
        }
        var elapsed = (now - pressedAt).toFloat() / SosConfig.HOLD_DURATION_MS;
        return elapsed > 1.0 ? 1.0 : elapsed;
    }

    // True exactly once, when a hold reaches SosConfig.HOLD_DURATION_MS. The press then ends, so
    // the button looks released even while it is still held down.
    function update(now as Number) as Boolean {
        var pressedAt = _pressedAt;
        if (pressedAt != null && now - pressedAt >= SosConfig.HOLD_DURATION_MS) {
            _pressedAt = null;
            return true;
        }
        return false;
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
