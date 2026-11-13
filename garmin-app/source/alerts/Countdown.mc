import Toybox.Lang;
import Toybox.Timer;

// Receives the seconds left on every tick, from the starting value down to 0.
typedef CountdownTickListener as Method(remaining as Number) as Void;
typedef CountdownCompleteListener as Method() as Void;

// Port of src/core/countdown.js (Countdown.kt in wear-app): counts down whole seconds with a
// repeating Toybox.Timer.Timer, created on start() and released when the countdown ends, since
// apps may only have a few timers. Ticks report the seconds left, from the starting value to 0;
// at 0 the countdown completes. tick() is public so tests can advance it without waiting.
class Countdown {
    static const TICK_MS = 1000;

    private var _onTick as CountdownTickListener;
    private var _onComplete as CountdownCompleteListener;
    private var _timer as Timer.Timer or Null = null;
    private var _remaining as Number = 0;

    function initialize(onTick as CountdownTickListener, onComplete as CountdownCompleteListener) {
        _onTick = onTick;
        _onComplete = onComplete;
    }

    function isRunning() as Boolean {
        return _timer != null;
    }

    // Seconds left while running; null when not running.
    function remaining() as Number or Null {
        return isRunning() ? _remaining : null;
    }

    // Reports the starting value at once, then one second less on every tick. Ignored while
    // running, so a second start can never restart or double the countdown.
    function start(seconds as Number) as Void {
        if (isRunning()) {
            return;
        }
        _remaining = seconds;
        var timer = new Timer.Timer();
        timer.start(method(:tick), TICK_MS, true);
        _timer = timer;
        report();
    }

    // Stops without completing. Does nothing when not running.
    function cancel() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    // Called by the timer once a second.
    function tick() as Void {
        if (isRunning()) {
            _remaining -= 1;
            report();
        }
    }

    private function report() as Void {
        _onTick.invoke(_remaining);
        // A tick listener may have cancelled the countdown, which must then not complete.
        if (_remaining <= 0 && isRunning()) {
            cancel();
            _onComplete.invoke();
        }
    }
}
