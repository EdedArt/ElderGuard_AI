import Toybox.Lang;
import Toybox.Test;

// The heart rate anomaly detector and monitor, mirroring tests/heartRateAnomalyDetector.test.js,
// tests/heartRateMonitor.test.js and HeartRateAnomalyDetectorTest.kt in wear-app.

// A warning-level detector, the time of its readings and what it reported.
(:test)
class AnomalyHarness {
    static const HIGH = HeartRateAnomalyConfig.BPM_THRESHOLD + 10;

    var detector as HeartRateAnomalyDetector = HeartRateAnomalyDetector.warning();
    var time as Number = 0;
    var warnings as Number = 0;
    var resolutions as Number = 0;

    function initialize() {
    }

    // One reading, elapsedMs after the previous one.
    function sample(bpm as Number, reading as Accelerometer, elapsedMs as Number) as Void {
        time += elapsedMs;
        var event = detector.process(bpm, reading, time);
        if (event == ANOMALY_EVENT_WARNING) {
            warnings++;
        } else if (event == ANOMALY_EVENT_RESOLVED) {
            resolutions++;
        }
    }

    // A reading at rest, a second after the previous one.
    function still(bpm as Number) as Void {
        sample(bpm, TestReadings.still(), 1000);
    }

    function repeat(count as Number, bpm as Number, reading as Accelerometer) as Void {
        for (var i = 0; i < count; i++) {
            sample(bpm, reading, 1000);
        }
    }

    function reachWarning() as Void {
        still(HIGH);
        sample(HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS);
    }

    function state() as AnomalyState {
        return detector.getState();
    }
}

// --- Configuration ---

(:test)
function anomaly_hasTheAgreedValuesSharingTheStillnessToleranceOfTheFallDetector(logger as Logger) as Boolean {
    Test.assertEqual(HeartRateAnomalyConfig.BPM_THRESHOLD, 120);
    Test.assertEqual(HeartRateAnomalyConfig.SUSTAINED_DURATION_MS, 8000);
    Test.assertEqual(HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G, FallDetectionConfig.IMMOBILITY_TOLERANCE_G);
    Test.assertEqual(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD, 160);
    Test.assert(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD > HeartRateAnomalyConfig.BPM_THRESHOLD);
    return true;
}

// --- Reaching the warning ---

(:test)
function anomaly_startsNormal(logger as Logger) as Boolean {
    Test.assertEqual(new AnomalyHarness().state(), ANOMALY_NORMAL);
    return true;
}

(:test)
function anomaly_sustainedHighBpmAtRestWarnsCountingFromTheFirstHighSample(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.still(AnomalyHarness.HIGH);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    Test.assertEqual(h.warnings, 0);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), 1);
    Test.assertEqual(h.state(), ANOMALY_WARNING);
    Test.assertEqual(h.warnings, 1);
    return true;
}

(:test)
function anomaly_warnsOnlyOnceWhileTheConditionLasts(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.reachWarning();
    h.repeat(20, AnomalyHarness.HIGH, TestReadings.still());
    Test.assertEqual(h.warnings, 1);
    return true;
}

(:test)
function anomaly_needsTheHeartRateAboveTheThresholdNotAtIt(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.repeat(20, HeartRateAnomalyConfig.BPM_THRESHOLD, TestReadings.still());
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    h.still(HeartRateAnomalyConfig.BPM_THRESHOLD + 1);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    return true;
}

// --- What does not warn ---

(:test)
function anomaly_ignoresNormalHeartRates(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.repeat(30, 70, TestReadings.still());
    Test.assertEqual(h.warnings, 0);
    return true;
}

(:test)
function anomaly_aBriefSpikeDoesNotWarnAndTheCountStartsOverAfterIt(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.still(AnomalyHarness.HIGH);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1000);
    h.still(70);
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    h.still(AnomalyHarness.HIGH);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1);
    Test.assertEqual(h.warnings, 0);
    return true;
}

(:test)
function anomaly_movementPreventsTheWarningHoweverLongItLasts(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.repeat(30, AnomalyHarness.HIGH, TestReadings.moving());
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    Test.assertEqual(h.warnings, 0);
    return true;
}

(:test)
function anomaly_movementInterruptingTheCountStartsItOver(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.still(AnomalyHarness.HIGH);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1000);
    h.sample(AnomalyHarness.HIGH, TestReadings.moving(), 1000);
    h.still(AnomalyHarness.HIGH);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1);
    Test.assertEqual(h.warnings, 0);
    return true;
}

(:test)
function anomaly_treatsTheEdgeOfTheToleranceAsRestingAndPastItAsMoving(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.sample(AnomalyHarness.HIGH, TestReadings.z(1.0d + HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G), 1000);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    h.sample(AnomalyHarness.HIGH, TestReadings.z(1.0d + HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G + 0.01d), 1000);
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    return true;
}

(:test)
function anomaly_countsAnyOrientationAsRestingSinceOnlyTheMagnitudeMatters(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.sample(AnomalyHarness.HIGH, new Accelerometer(0.6d, 0.8d, 0.0d), 1000);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    return true;
}

// --- Going back to normal ---

(:test)
function anomaly_resolvesWhenTheHeartRateDrops(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.reachWarning();
    h.still(70);
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    Test.assertEqual(h.resolutions, 1);
    return true;
}

(:test)
function anomaly_resolvesWhenMovementResumes(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.reachWarning();
    h.sample(AnomalyHarness.HIGH, TestReadings.moving(), 1000);
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    Test.assertEqual(h.resolutions, 1);
    return true;
}

(:test)
function anomaly_doesNotReportResolvedIfNoWarningHadBeenGiven(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.still(AnomalyHarness.HIGH);
    h.still(70);
    Test.assertEqual(h.resolutions, 0);
    return true;
}

(:test)
function anomaly_canWarnAgainAfterTheFullTime(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.reachWarning();
    h.still(70);
    h.reachWarning();
    Test.assertEqual(h.warnings, 2);
    return true;
}

// --- Reset ---

(:test)
function anomaly_resetGoesBackToNormalWithoutReportingAnything(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.reachWarning();
    h.detector.reset();
    Test.assertEqual(h.state(), ANOMALY_NORMAL);
    Test.assertEqual(h.resolutions, 0);
    return true;
}

(:test)
function anomaly_resetForgetsTheTimeAlreadyCounted(logger as Logger) as Boolean {
    var h = new AnomalyHarness();
    h.still(AnomalyHarness.HIGH);
    h.sample(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS - 1000);
    h.detector.reset();
    h.still(AnomalyHarness.HIGH);
    Test.assertEqual(h.state(), ANOMALY_ELEVATED);
    Test.assertEqual(h.warnings, 0);
    return true;
}

// --- Other thresholds ---

(:test)
function anomaly_takesItsThresholdsFromItsParameters(logger as Logger) as Boolean {
    var critical = new HeartRateAnomalyDetector(160, 2000, HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G);
    Test.assert(critical.process(150, TestReadings.still(), 0) == null);
    Test.assert(critical.process(150, TestReadings.still(), 5000) == null);
    Test.assert(critical.process(170, TestReadings.still(), 6000) == null);
    Test.assert(critical.process(170, TestReadings.still(), 8000) == ANOMALY_EVENT_WARNING);
    var standard = HeartRateAnomalyDetector.critical();
    standard.process(150, TestReadings.still(), 0);
    Test.assertEqual(standard.getState(), ANOMALY_NORMAL);
    standard.process(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD + 1, TestReadings.still(), 1000);
    Test.assertEqual(standard.getState(), ANOMALY_ELEVATED);
    return true;
}

// --- Fed from the store (HeartRateMonitor) ---

// A store with a heart rate monitor, written to one reading per second.
(:test)
class HeartRateMonitorHarness {
    var store as TelemetryStore = new TelemetryStore();
    var clock as FakeClock = new FakeClock();
    var monitor as HeartRateMonitor;

    function initialize() {
        monitor = new HeartRateMonitor(store, HeartRateAnomalyDetector.warning(), clock);
    }

    // One engine tick: the heart rate, the accelerometer and a new lastUpdate in one update.
    function reading(bpm as Number, accelerometer as Accelerometer) as Void {
        clock.time += 1000;
        var next = store.getState();
        var status = next.deviceStatus;
        next.heartRate = new HeartRate(bpm);
        next.accelerometer = accelerometer;
        next.deviceStatus = new DeviceStatus(status.mode, clock.time.toLong(), status.healthAlert);
        store.update(next);
    }

    function hold(bpm as Number, accelerometer as Accelerometer, seconds as Number) as Void {
        for (var i = 0; i < seconds; i++) {
            reading(bpm, accelerometer);
        }
    }

    function healthAlert() as HealthAlert or Null {
        return store.getState().deviceStatus.healthAlert;
    }
}

(:test)
function anomalyMonitor_setsAndClearsTheHealthAlertInTheStore(logger as Logger) as Boolean {
    var h = new HeartRateMonitorHarness();
    var seconds = HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000;
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), seconds);
    Test.assert(h.healthAlert() == null);
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), 1);
    Test.assert(h.healthAlert() == HEALTH_ALERT_HIGH_HEART_RATE);
    Test.assertEqual(h.monitor.getDetectorState(), ANOMALY_WARNING);
    // A warning, not an alert: the device mode stays as it is.
    Test.assertEqual(h.store.getState().deviceStatus.mode, MODE_MONITORING);
    h.hold(70, TestReadings.still(), 1);
    Test.assert(h.healthAlert() == null);
    return true;
}

(:test)
function anomalyMonitor_movementClearsTheWarning(logger as Logger) as Boolean {
    var h = new HeartRateMonitorHarness();
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000 + 1);
    Test.assert(h.healthAlert() == HEALTH_ALERT_HIGH_HEART_RATE);
    h.hold(AnomalyHarness.HIGH, TestReadings.moving(), 1);
    Test.assert(h.healthAlert() == null);
    return true;
}

(:test)
function anomalyMonitor_resetClearsTheWarning(logger as Logger) as Boolean {
    var h = new HeartRateMonitorHarness();
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000 + 1);
    h.monitor.reset();
    Test.assert(h.healthAlert() == null);
    // Clearing the alert is itself a store update, so a rate still high starts a new count at
    // once (as in the web app); the warning only comes back after the full time again.
    Test.assert(h.monitor.getDetectorState() != ANOMALY_WARNING);
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000 - 1);
    Test.assert(h.healthAlert() == null);
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), 1);
    Test.assert(h.healthAlert() == HEALTH_ALERT_HIGH_HEART_RATE);
    return true;
}

(:test)
function anomalyMonitor_runsAlongsideAFallCountdown(logger as Logger) as Boolean {
    var h = new HeartRateMonitorHarness();
    h.store.setMode(MODE_FALL_COUNTDOWN);
    h.hold(AnomalyHarness.HIGH, TestReadings.still(), HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000 + 1);
    Test.assert(h.healthAlert() == HEALTH_ALERT_HIGH_HEART_RATE);
    Test.assertEqual(h.store.getState().deviceStatus.mode, MODE_FALL_COUNTDOWN);
    return true;
}
