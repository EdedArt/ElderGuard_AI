import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// What the watchface does with input, kept apart from drawing (WatchfaceView) and from the
// device events (WatchfaceDelegate), so tests can drive it with plain method calls.
//
// It owns the only timer of the watchface. The timer runs only while the SOS control is pressed
// or its hint is showing: every frame it advances the progress ring and checks whether the hold
// is complete. It stops as soon as both end; the rest of the time the view redraws only on
// telemetry updates.
class WatchfaceController {
    static const FRAME_MS = 100;

    var hold as SosHold = new SosHold();
    private var _sos as SosController;
    private var _timer as Timer.Timer or Null = null;

    function initialize(sos as SosController) {
        _sos = sos;
    }

    function sosPress() as Void {
        if (!hold.isPressed()) {
            buzz(50);
        }
        hold.press(now());
        changed();
    }

    function sosRelease() as Void {
        var time = now();
        // A release right at the end of the hold still counts, even before the next frame.
        if (hold.update(time)) {
            activate();
        } else {
            hold.release(time);
        }
        changed();
    }

    function sosTap() as Void {
        hold.tap(now());
        changed();
    }

    // Called by the timer while animating.
    function onFrame() as Void {
        if (hold.update(now())) {
            activate();
        }
        changed();
    }

    // Milliseconds from System.getTimer(). A method of its own so tests can replace the clock.
    function now() as Number {
        return System.getTimer();
    }

    // Stops the timer, for when the watchface is hidden.
    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    private function activate() as Void {
        buzz(600);
        _sos.activate();
    }

    // A vibration of this many milliseconds, on watches that can vibrate.
    private function buzz(durationMs as Number) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, durationMs)]);
        }
    }

    private function changed() as Void {
        if (hold.isAnimating(now())) {
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
