import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// The time the detectors and alerts read, passed in so tests can replace it with one they set.
class Clock {
    function initialize() {
    }

    // Milliseconds from System.getTimer(): monotonic and with millisecond resolution, for
    // measuring how long something lasts. Time.now() only has whole seconds.
    function now() as Number {
        return System.getTimer();
    }

    // Epoch milliseconds, for the timestamps alerts carry, as in the other apps. Time.now() has a
    // resolution of one second.
    function epochMs() as Long {
        return Time.now().value().toLong() * 1000l;
    }
}
