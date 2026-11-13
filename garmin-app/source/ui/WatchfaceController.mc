import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// What the watchface does with input, kept apart from drawing (WatchfaceView) and from the
// device events (WatchfaceDelegate), so tests can drive it with plain method calls.
//
// It owns the only timer of the watchface. The timer runs only while the SOS control is pressed
// or its hint is showing, redrawing the screen for the feedback, and stops as soon as both end;
// the rest of the time the view redraws only on telemetry updates.
class WatchfaceController {
    static const FRAME_MS = 100;

    var hold as SosHold = new SosHold();
    private var _timer as Timer.Timer or Null = null;

    function initialize() {
    }

    function sosPress() as Void {
        hold.press(System.getTimer());
        changed();
    }

    function sosRelease() as Void {
        hold.release(System.getTimer());
        changed();
    }

    function sosTap() as Void {
        hold.tap(System.getTimer());
        changed();
    }

    // Called by the timer while animating.
    function onFrame() as Void {
        changed();
    }

    // Stops the timer, for when the watchface is hidden.
    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    private function changed() as Void {
        if (hold.isAnimating(System.getTimer())) {
            if (_timer == null) {
                var timer = new Timer.Timer();
                timer.start(method(:onFrame), FRAME_MS, true);
                _timer = timer;
            }
        } else {
            stop();
        }
        WatchUi.requestUpdate();
    }
}
