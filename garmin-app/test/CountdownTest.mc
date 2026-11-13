import Toybox.Lang;
import Toybox.Test;

// The countdown, mirroring tests/countdown.test.js and CountdownTest.kt in wear-app. The tests
// call tick() for each second instead of waiting for the timer, and always leave the countdown
// stopped, so no timer outlives its test.

// A countdown with listeners that record what it reports.
(:test)
class CountdownHarness {
    var countdown as Countdown;
    var seen as Array<Number> = [] as Array<Number>;
    var completed as Number = 0;
    // When set, the tick listener cancels the countdown on reaching this value.
    var cancelAt as Number or Null = null;

    function initialize() {
        countdown = new Countdown(method(:onTick), method(:onComplete));
    }

    function onTick(remaining as Number) as Void {
        seen.add(remaining);
        if (cancelAt != null && remaining == cancelAt) {
            countdown.cancel();
        }
    }

    function onComplete() as Void {
        completed++;
    }

    function ticks(count as Number) as Void {
        for (var i = 0; i < count; i++) {
            countdown.tick();
        }
    }

    function finish() as Void {
        countdown.cancel();
    }
}

(:test)
function countdown_isNotRunningUntilStarted(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    Test.assert(!h.countdown.isRunning());
    Test.assert(h.countdown.remaining() == null);
    h.ticks(3);
    Test.assertEqual(h.seen.size(), 0);
    return true;
}

(:test)
function countdown_reportsTheStartingValueRightAway(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(3);
    Test.assertEqual(h.seen.toString(), [3].toString());
    Test.assert(h.countdown.isRunning());
    Test.assert(h.countdown.remaining() == 3);
    h.finish();
    return true;
}

(:test)
function countdown_countsDownOncePerSecondToZeroAndThenCompletesOnce(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(3);
    h.ticks(1);
    Test.assertEqual(h.seen.toString(), [3, 2].toString());
    h.ticks(1);
    Test.assertEqual(h.completed, 0);
    h.ticks(1);
    Test.assertEqual(h.seen.toString(), [3, 2, 1, 0].toString());
    Test.assertEqual(h.completed, 1);
    Test.assert(!h.countdown.isRunning());
    // A stray tick after completing does nothing.
    h.ticks(1);
    Test.assertEqual(h.completed, 1);
    Test.assertEqual(h.seen.size(), 4);
    return true;
}

(:test)
function countdown_ignoresASecondStartWhileRunning(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(3);
    h.ticks(1);
    h.countdown.start(10);
    h.ticks(5);
    Test.assertEqual(h.seen.toString(), [3, 2, 1, 0].toString());
    Test.assertEqual(h.completed, 1);
    return true;
}

(:test)
function countdown_canStartAgainAfterCompleting(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(1);
    h.ticks(1);
    h.countdown.start(1);
    h.ticks(1);
    Test.assertEqual(h.completed, 2);
    return true;
}

(:test)
function countdown_completesRightAwayFromZero(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(0);
    Test.assertEqual(h.completed, 1);
    Test.assert(!h.countdown.isRunning());
    return true;
}

(:test)
function countdown_cancelStopsTheTicksAndNeverCompletes(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(3);
    h.ticks(1);
    h.countdown.cancel();
    h.ticks(5);
    Test.assertEqual(h.seen.toString(), [3, 2].toString());
    Test.assertEqual(h.completed, 0);
    Test.assert(!h.countdown.isRunning());
    Test.assert(h.countdown.remaining() == null);
    return true;
}

(:test)
function countdown_cancelDoesNothingWhenNotRunning(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.cancel();
    Test.assert(!h.countdown.isRunning());
    return true;
}

(:test)
function countdown_cancelAllowsANewStartFromTheFullValue(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(3);
    h.ticks(1);
    h.countdown.cancel();
    h.countdown.start(3);
    Test.assertEqual(h.seen.toString(), [3, 2, 3].toString());
    h.finish();
    return true;
}

(:test)
function countdown_cancellingOnTheLastSecondPreventsCompletion(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.cancelAt = 0;
    h.countdown.start(1);
    h.ticks(1);
    Test.assertEqual(h.completed, 0);
    Test.assert(!h.countdown.isRunning());
    return true;
}

(:test)
function countdown_usesTheConfiguredSeconds(logger as Logger) as Boolean {
    var h = new CountdownHarness();
    h.countdown.start(FallDetectionConfig.COUNTDOWN_SECONDS);
    h.ticks(FallDetectionConfig.COUNTDOWN_SECONDS - 1);
    Test.assertEqual(h.completed, 0);
    Test.assert(h.countdown.remaining() == 1);
    h.ticks(1);
    Test.assertEqual(h.completed, 1);
    Test.assertEqual(h.seen.size(), FallDetectionConfig.COUNTDOWN_SECONDS + 1);
    return true;
}
