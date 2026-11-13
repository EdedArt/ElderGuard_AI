import Toybox.Lang;
import Toybox.Test;

// The fall detector, mirroring tests/fallDetector.test.js and FallDetectorTest.kt in wear-app.
// Times are passed in with each reading, so every scenario runs instantly.

// A detector and how many falls it has confirmed.
(:test)
class FallHarness {
    var detector as FallDetector;
    var confirmed as Number = 0;

    function initialize() {
        detector = FallDetector.standard();
    }

    function feed(timestamp as Number, reading as Accelerometer) as Void {
        if (detector.process(reading, timestamp)) {
            confirmed++;
        }
    }

    // A reading once per second over [from, to], like the telemetry engine.
    function feedEverySecond(from as Number, to as Number, reading as Accelerometer) as Void {
        for (var t = from; t <= to; t += 1000) {
            feed(t, reading);
        }
    }

    // An impact at start and stillness long enough to confirm it.
    function fallFrom(start as Number) as Void {
        feed(start, TestReadings.spike());
        feedEverySecond(start + 1000, start + 1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    }

    function state() as FallState {
        return detector.getState();
    }
}

// --- Real fall ---

(:test)
function fall_aRealFallWalksThroughEveryStateAndConfirmsOnce(logger as Logger) as Boolean {
    var h = new FallHarness();
    Test.assertEqual(h.state(), FALL_IDLE);
    h.feed(0, TestReadings.spike());
    Test.assertEqual(h.state(), FALL_IMPACT);
    h.feed(1000, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IMMOBILITY);
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS - 1, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IMMOBILITY);
    Test.assertEqual(h.confirmed, 0);
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    Test.assertEqual(h.state(), FALL_CONFIRMED);
    Test.assertEqual(h.confirmed, 1);
    return true;
}

(:test)
function fall_confirmsWithStillnessInAnyOrientationOfTheWatch(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feedEverySecond(1000, 1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, new Accelerometer(1.0d, 0.0d, 0.0d));
    Test.assertEqual(h.confirmed, 1);
    return true;
}

(:test)
function fall_acceptsSmallNoiseWithinTheTolerance(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.z(1.0d + FallDetectionConfig.IMMOBILITY_TOLERANCE_G - 0.01d));
    h.feed(2000, TestReadings.z(1.0d - FallDetectionConfig.IMMOBILITY_TOLERANCE_G + 0.01d));
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    Test.assertEqual(h.confirmed, 1);
    return true;
}

(:test)
function fall_acceptsASpikeExactlyAtTheThreshold(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.z(FallDetectionConfig.IMPACT_THRESHOLD_G));
    Test.assertEqual(h.state(), FALL_IMPACT);
    return true;
}

(:test)
function fall_staysConfirmedAndDoesNotConfirmAgainUntilReset(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.fallFrom(0);
    h.fallFrom(10000);
    Test.assertEqual(h.state(), FALL_CONFIRMED);
    Test.assertEqual(h.confirmed, 1);
    return true;
}

// --- False alarms ---

(:test)
function fall_aSpikeFollowedByMovementDoesNotConfirm(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feedEverySecond(1000,
        1000 + FallDetectionConfig.IMMOBILITY_START_WINDOW_MS + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.moving());
    Test.assertEqual(h.state(), FALL_IDLE);
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_anyMovementDuringImmobilityReturnsToIdle(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.still());
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS - 1, TestReadings.moving());
    Test.assertEqual(h.state(), FALL_IDLE);
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    h.feed(1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS * 2, TestReadings.still());
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_stillnessWithoutASpikeDoesNotConfirm(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feedEverySecond(0, FallDetectionConfig.IMMOBILITY_DURATION_MS * 3, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IDLE);
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_aSlowSitDownBelowTheThresholdDoesNotConfirm(logger as Logger) as Boolean {
    var h = new FallHarness();
    var sitDown = [1.0d, 1.2d, 1.6d, 2.1d, FallDetectionConfig.IMPACT_THRESHOLD_G - 0.01d, 1.8d, 1.3d, 1.0d];
    for (var i = 0; i < sitDown.size(); i++) {
        h.feed(i * 500, TestReadings.z(sitDown[i] as Double));
    }
    Test.assertEqual(h.state(), FALL_IDLE);
    h.feedEverySecond(5000, 5000 + FallDetectionConfig.IMMOBILITY_DURATION_MS * 2, TestReadings.still());
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_stillnessThatStartsTooLateDoesNotConfirm(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.moving());
    h.feed(FallDetectionConfig.IMMOBILITY_START_WINDOW_MS + 1, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IDLE);
    h.feedEverySecond(FallDetectionConfig.IMMOBILITY_START_WINDOW_MS + 1001,
        FallDetectionConfig.IMMOBILITY_DURATION_MS * 3, TestReadings.still());
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_acceptsStillnessThatStartsAtTheVeryEndOfTheWindow(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(FallDetectionConfig.IMMOBILITY_START_WINDOW_MS, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IMMOBILITY);
    return true;
}

// --- Repeated impacts ---

(:test)
function fall_restartsTheWindowFromTheLatestImpact(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(2000, TestReadings.spike());
    h.feed(2000 + FallDetectionConfig.IMMOBILITY_START_WINDOW_MS, TestReadings.still());
    Test.assertEqual(h.state(), FALL_IMMOBILITY);
    return true;
}

(:test)
function fall_aSecondImpactDuringImmobilityRestartsTheSequence(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.still());
    h.feed(2000, TestReadings.spike());
    Test.assertEqual(h.state(), FALL_IMPACT);
    h.feed(3000, TestReadings.still());
    h.feed(3000 + FallDetectionConfig.IMMOBILITY_DURATION_MS - 1, TestReadings.still());
    Test.assertEqual(h.confirmed, 0);
    h.feed(3000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    Test.assertEqual(h.confirmed, 1);
    return true;
}

(:test)
function fall_canDetectAFallAfterAnEarlierFalseAlarm(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.still());
    h.feed(2000, TestReadings.moving());
    h.fallFrom(3000);
    Test.assertEqual(h.confirmed, 1);
    return true;
}

// --- Reset ---

(:test)
function fall_resetReturnsToIdleFromEveryState(logger as Logger) as Boolean {
    var states = [FALL_IMPACT, FALL_IMMOBILITY, FALL_CONFIRMED];
    for (var i = 0; i < states.size(); i++) {
        var h = new FallHarness();
        h.feed(0, TestReadings.spike());
        if (i >= 1) {
            h.feed(1000, TestReadings.still());
        }
        if (i == 2) {
            h.feedEverySecond(2000, 1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
        }
        Test.assertEqual(h.state(), states[i]);
        h.detector.reset();
        Test.assertEqualMessage(h.state(), FALL_IDLE, "reset from state " + states[i]);
    }
    return true;
}

(:test)
function fall_resetForgetsAFallInProgress(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.feed(0, TestReadings.spike());
    h.feed(1000, TestReadings.still());
    h.detector.reset();
    h.feedEverySecond(2000, 2000 + FallDetectionConfig.IMMOBILITY_DURATION_MS, TestReadings.still());
    Test.assertEqual(h.confirmed, 0);
    return true;
}

(:test)
function fall_resetAllowsANewDetectionAfterAConfirmedFall(logger as Logger) as Boolean {
    var h = new FallHarness();
    h.fallFrom(0);
    h.detector.reset();
    h.fallFrom(20000);
    Test.assertEqual(h.confirmed, 2);
    return true;
}

// --- Configuration ---

(:test)
function fall_hasTheDocumentedDefaultValues(logger as Logger) as Boolean {
    Test.assertEqual(FallDetectionConfig.IMPACT_THRESHOLD_G, 2.5d);
    Test.assertEqual(FallDetectionConfig.IMMOBILITY_TOLERANCE_G, 0.15d);
    Test.assertEqual(FallDetectionConfig.IMMOBILITY_DURATION_MS, 5000);
    Test.assertEqual(FallDetectionConfig.IMMOBILITY_START_WINDOW_MS, 3000);
    Test.assertEqual(FallDetectionConfig.COUNTDOWN_SECONDS, 10);
    Test.assertEqual(FallDetectionConfig.URGENT_SECONDS, 3);
    return true;
}

(:test)
function fall_takesEveryThresholdFromItsParameters(logger as Logger) as Boolean {
    var custom = new FallDetector(5.0d, 0.5d, 100, 50);
    custom.process(TestReadings.z(4.0d), 0);
    Test.assertEqual(custom.getState(), FALL_IDLE);
    custom.process(TestReadings.z(5.0d), 0);
    Test.assertEqual(custom.getState(), FALL_IMPACT);
    custom.process(TestReadings.z(1.4d), 50);
    Test.assertEqual(custom.getState(), FALL_IMMOBILITY);
    Test.assert(custom.process(TestReadings.z(0.6d), 150));
    return true;
}

// --- Fed from the store (FallMonitor) ---

(:test)
function fallFeed_confirmsAFallFedThroughTheStore(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var clock = new FakeClock();
    var monitor = new FallMonitor(store, FallDetector.standard(), clock);
    TestReadings.write(store, clock, TestReadings.spike(), 1000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IMPACT);
    TestReadings.write(store, clock, TestReadings.still(), 2000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IMMOBILITY);
    // Identical readings: only lastUpdate changes, which still makes each a new sample.
    TestReadings.write(store, clock, TestReadings.still(), 2000 + FallDetectionConfig.IMMOBILITY_DURATION_MS - 1000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IMMOBILITY);
    TestReadings.write(store, clock, TestReadings.still(), 2000 + FallDetectionConfig.IMMOBILITY_DURATION_MS);
    // Confirmed: the watch switches to the fall countdown, and the detector rests until it ends.
    Test.assertEqual(store.getState().deviceStatus.mode, MODE_FALL_COUNTDOWN);
    Test.assertEqual(monitor.getDetectorState(), FALL_IDLE);
    monitor.cancel();
    return true;
}

(:test)
function fallFeed_ignoresReadingsAndForgetsTheSequenceWhileNotMonitoring(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var clock = new FakeClock();
    var sos = new SosController(store);
    var monitor = new FallMonitor(store, FallDetector.standard(), clock);
    TestReadings.write(store, clock, TestReadings.spike(), 0);
    TestReadings.write(store, clock, TestReadings.still(), 1000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IMMOBILITY);

    sos.activate();
    Test.assertEqual(monitor.getDetectorState(), FALL_IDLE);
    TestReadings.write(store, clock, TestReadings.spike(), 2000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IDLE);

    sos.cancel();
    // The first reading back in monitoring dates from the alert, so it is skipped.
    Test.assertEqual(monitor.getDetectorState(), FALL_IDLE);
    TestReadings.write(store, clock, TestReadings.spike(), 20000);
    Test.assertEqual(monitor.getDetectorState(), FALL_IMPACT);
    return true;
}
