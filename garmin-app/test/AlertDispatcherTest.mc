import Toybox.Lang;
import Toybox.Test;

// The alert dispatcher, mirroring tests/alertDispatcher.test.js and AlertDispatcherTest.kt in
// wear-app on a whole device: the real store, SOS, fall and heart rate monitors and dispatcher,
// with a fake clock. second() is one engine tick and, while it runs, one second of the countdown.

(:test)
class DeviceHarness {
    static const CRITICAL = HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD + 10;

    var store as TelemetryStore = new TelemetryStore();
    var clock as FakeClock = new FakeClock();
    var sos as SosController;
    var fall as FallMonitor;
    var heartRate as HeartRateMonitor;
    var alerts as AlertDispatcher;

    // What the next ticks write, like engine overrides.
    var bpm as Number = 70;
    var accelerometer as Accelerometer = TestReadings.still();
    var gps as Gps = new Gps(4.6097d, -74.0817d, 3.0d, true);
    var battery as Battery = new Battery(80.0d, false);

    function initialize() {
        clock.time = 100000;
        sos = new SosController(store);
        fall = new FallMonitor(store, sos, FallDetector.standard(), clock);
        heartRate = new HeartRateMonitor(store, HeartRateAnomalyDetector.warning(), clock);
        alerts = new AlertDispatcher(store, sos, HeartRateAnomalyDetector.critical(), clock);
    }

    function second() as Void {
        var countdownRunning = fall.countdown().isRunning();
        clock.time += 1000;
        var next = store.getState();
        next.heartRate = new HeartRate(bpm);
        next.accelerometer = accelerometer;
        next.gps = gps;
        next.battery = battery;
        next.deviceStatus = new DeviceStatus(next.deviceStatus.mode, clock.time.toLong(), next.deviceStatus.healthAlert);
        store.update(next);
        if (countdownRunning) {
            fall.countdown().tick();
        }
    }

    function seconds(count as Number) as Void {
        for (var i = 0; i < count; i++) {
            second();
        }
    }

    // A spike for a tick, then stillness until the countdown starts.
    function simulateFall() as Void {
        accelerometer = TestReadings.spike();
        second();
        accelerometer = TestReadings.still();
        seconds(FallDetectionConfig.IMMOBILITY_DURATION_MS / 1000 + 1);
    }

    function holdRate(rate as Number, reading as Accelerometer) as Void {
        bpm = rate;
        accelerometer = reading;
    }

    function mode() as DeviceMode {
        return store.getState().deviceStatus.mode;
    }

    function count() as Number {
        return alerts.alerts().size();
    }

    function finish() as Void {
        fall.countdown().cancel();
    }
}

// Seconds of rate at rest until the critical alert goes out: the first high sample starts the
// count, and the warning comes SUSTAINED_DURATION_MS later.
(:test)
class Times {
    static function toConfirm() as Number {
        return HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000 + 1;
    }
}

(:test)
function dispatcher_theCriticalThresholdIsAboveTheWarningOne(logger as Logger) as Boolean {
    Test.assertEqual(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD, 160);
    Test.assert(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD > HeartRateAnomalyConfig.BPM_THRESHOLD);
    return true;
}

// --- Alerts that go out ---

(:test)
function dispatcher_aFallSosProducesACorrectlyShapedAlert(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.simulateFall();
    Test.assertEqual(d.mode(), MODE_FALL_COUNTDOWN);
    Test.assertEqual(d.count(), 0);
    d.seconds(FallDetectionConfig.COUNTDOWN_SECONDS);
    Test.assertEqual(d.mode(), MODE_SOS);
    Test.assertEqual(d.count(), 1);
    var alert = d.alerts.alerts()[0];
    var state = d.store.getState();
    Test.assertEqual(AlertPayloads.typeId(alert.type), "fall");
    Test.assertEqual(alert.timestamp, d.clock.time.toLong());
    Test.assert(alert.gps.equals(state.gps));
    Test.assertEqual(alert.heartRate, 70);
    Test.assertEqual(alert.batteryLevel, 80);
    Test.assertEqual(alert.contacts.size(), 3);
    Test.assertEqual(alert.contacts[2].name, "Dra. Prueba");
    // The SOS screen confirms this one.
    Test.assert(d.alerts.sosAlert() == alert);
    return true;
}

(:test)
function dispatcher_aManualSosProducesACorrectlyShapedAlert(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.seconds(3);
    d.sos.activate(SOS_REASON_MANUAL);
    Test.assertEqual(d.count(), 1);
    var alert = d.alerts.alerts()[0];
    Test.assertEqual(AlertPayloads.typeId(alert.type), "manual-sos");
    Test.assertEqual(alert.timestamp, d.clock.time.toLong());
    Test.assertEqual(alert.contacts.size(), 3);
    return true;
}

(:test)
function dispatcher_aSustainedCriticalHeartRateProducesAnAlertWithNoSos(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
    d.seconds(Times.toConfirm() - 1);
    Test.assertEqual(d.count(), 0);
    Test.assert(!d.alerts.isCriticalActive());
    d.second();
    Test.assertEqual(d.count(), 1);
    var alert = d.alerts.alerts()[0];
    Test.assertEqual(AlertPayloads.typeId(alert.type), "high-heart-rate");
    Test.assertEqual(alert.heartRate, DeviceHarness.CRITICAL);
    Test.assert(d.alerts.isCriticalActive());
    Test.assertEqual(d.mode(), MODE_MONITORING);
    Test.assert(d.alerts.sosAlert() == null);
    return true;
}

(:test)
function dispatcher_recordsTheBatteryAndLocationOfThatMomentNotLaterOnes(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.battery = new Battery(42.0d, false);
    d.gps = new Gps(1.0d, 2.0d, 5.0d, false);
    d.second();
    d.sos.activate(SOS_REASON_MANUAL);
    d.battery = new Battery(5.0d, false);
    d.gps = new Gps(3.0d, 4.0d, 5.0d, true);
    d.seconds(3);
    var alert = d.alerts.alerts()[0];
    Test.assertEqual(alert.batteryLevel, 42);
    Test.assert(alert.gps.equals(new Gps(1.0d, 2.0d, 5.0d, false)));
    return true;
}

(:test)
function dispatcher_keepsEveryAlertOldestFirst(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.sos.activate(SOS_REASON_MANUAL);
    d.sos.cancel();
    d.second();
    d.sos.activate(SOS_REASON_MANUAL);
    var all = d.alerts.alerts();
    Test.assertEqual(all.size(), 2);
    Test.assert(all[1].timestamp > all[0].timestamp);
    // The list handed out is a copy.
    all.add(all[0]);
    Test.assertEqual(d.count(), 2);
    return true;
}

// --- What does not send an alert ---

(:test)
function dispatcher_aResolvedAnomalyBelowTheCriticalThresholdSendsNothing(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(140, TestReadings.still());
    d.seconds(Times.toConfirm());
    Test.assert(d.store.getState().deviceStatus.healthAlert == HEALTH_ALERT_HIGH_HEART_RATE);
    d.bpm = 70;
    d.second();
    Test.assert(d.store.getState().deviceStatus.healthAlert == null);
    d.seconds(30);
    Test.assertEqual(d.count(), 0);
    return true;
}

(:test)
function dispatcher_aHeartRateExactlyAtTheCriticalThresholdSendsNothing(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD, TestReadings.still());
    d.seconds(Times.toConfirm() * 3);
    Test.assertEqual(d.count(), 0);
    return true;
}

(:test)
function dispatcher_aBriefCriticalSpikeSendsNothing(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
    d.seconds(Times.toConfirm() - 2);
    d.bpm = 70;
    d.seconds(30);
    Test.assertEqual(d.count(), 0);
    return true;
}

(:test)
function dispatcher_aCriticalHeartRateWhileMovingSendsNothing(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.moving());
    d.seconds(Times.toConfirm() * 3);
    Test.assertEqual(d.count(), 0);
    return true;
}

(:test)
function dispatcher_aFallCancelledInTimeSendsNothing(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.simulateFall();
    d.fall.cancel();
    d.seconds(FallDetectionConfig.COUNTDOWN_SECONDS * 2);
    Test.assertEqual(d.count(), 0);
    Test.assertEqual(d.mode(), MODE_MONITORING);
    return true;
}

// --- One alert per episode ---

(:test)
function dispatcher_doesNotRepeatWhileTheCriticalRateLasts(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
    d.seconds(Times.toConfirm() + 30);
    Test.assertEqual(d.count(), 1);
    return true;
}

(:test)
function dispatcher_sendsAnotherForANewEpisodeAndReportsTheEndOfTheFirst(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
    d.seconds(Times.toConfirm());
    Test.assert(d.alerts.isCriticalActive());
    d.bpm = 70;
    d.second();
    Test.assert(!d.alerts.isCriticalActive());
    d.bpm = DeviceHarness.CRITICAL;
    d.seconds(Times.toConfirm());
    Test.assertEqual(d.count(), 2);
    return true;
}

// --- Next to the fall flow ---

(:test)
function dispatcher_aCriticalAlertGoesOutDuringACountdownWhichCarriesOn(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.simulateFall();
    Test.assertEqual(d.mode(), MODE_FALL_COUNTDOWN);
    // A critical rate from the first second of the countdown completes its count before the
    // 10 seconds are over.
    d.bpm = DeviceHarness.CRITICAL;
    d.seconds(Times.toConfirm());
    Test.assertEqual(d.count(), 1);
    Test.assertEqual(d.alerts.alerts()[0].type, ALERT_HIGH_HEART_RATE);
    Test.assertEqual(d.mode(), MODE_FALL_COUNTDOWN);
    Test.assert(d.fall.countdown().isRunning());
    d.seconds(FallDetectionConfig.COUNTDOWN_SECONDS);
    var all = d.alerts.alerts();
    Test.assertEqual(all.size(), 2);
    Test.assertEqual(all[1].type, ALERT_FALL);
    // The SOS screen confirms the fall alert, not the health one.
    Test.assert(d.alerts.sosAlert() == all[1]);
    return true;
}

(:test)
function dispatcher_theNextSosDoesNotShowThePreviousConfirmation(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.sos.activate(SOS_REASON_MANUAL);
    Test.assert(d.alerts.sosAlert() != null);
    d.sos.cancel();
    Test.assert(d.alerts.sosAlert() == null);
    return true;
}

// --- Reset ---

(:test)
function dispatcher_resetClearsTheHistoryAndStopsTheCriticalCount(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.sos.activate(SOS_REASON_MANUAL);
    d.sos.cancel();
    d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
    d.seconds(3);
    d.alerts.reset();
    Test.assertEqual(d.count(), 0);
    d.seconds(Times.toConfirm() - 2);
    Test.assertEqual(d.count(), 0);
    return true;
}

// --- The critical banner on the watchface ---

(:test)
function dispatcher_aCriticalEpisodeTurnsTheBannerRedUntilItEnds(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var clock = new FakeClock();
    var monitor = new HeartRateMonitor(fixture.store, HeartRateAnomalyDetector.warning(), clock);
    // The fixture's dispatcher reads its own clock; drive both detectors with the same readings.
    var critical = new AlertDispatcher(fixture.store, fixture.sos, HeartRateAnomalyDetector.critical(), clock);
    var view = new WatchfaceView(fixture.store, fixture.language, fixture.controller, critical);
    view.onLayout(fixture.dc);
    for (var i = 0; i < Times.toConfirm(); i++) {
        clock.time += 1000;
        var next = fixture.store.getState();
        next.heartRate = new HeartRate(DeviceHarness.CRITICAL);
        next.deviceStatus = new DeviceStatus(MODE_MONITORING, clock.time.toLong(), next.deviceStatus.healthAlert);
        fixture.store.update(next);
    }
    Test.assertEqual(monitor.getDetectorState(), ANOMALY_WARNING);
    view.onUpdate(fixture.dc);
    var banner = view.heartRateBanner() as HeartRateBanner;
    Test.assert(banner.visible);
    Test.assert(banner.critical);
    Test.assertEqual(banner.text, "Pulso crítico: familia avisada");
    Test.assertEqual(banner.fill, WatchColors.DANGER);
    Test.assertEqual(banner.content, WatchColors.ON_DANGER);
    // Too long for the triangle, but still inside the screen.
    Test.assert(!banner.showsIcon(fixture.dc));
    Test.assert(banner.width(fixture.dc) <= new WatchfaceLayout(390, 390).bannerMaxWidth);

    var next = fixture.store.getState();
    next.heartRate = new HeartRate(70);
    fixture.store.update(next);
    view.onUpdate(fixture.dc);
    Test.assert(!banner.visible);
    fixture.finish();
    return true;
}

(:test)
function dispatcher_theCriticalBannerFitsInBothLanguages(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var layout = new WatchfaceLayout(390, 390);
    var banner = new HeartRateBanner(layout);
    banner.setCritical(true);
    var texts = ["Pulso crítico: familia avisada", "Critical pulse: family notified"];
    for (var i = 0; i < texts.size(); i++) {
        banner.text = texts[i] as String;
        var width = banner.width(fixture.dc);
        logger.debug(banner.text + ": " + width + " px, at most " + layout.bannerMaxWidth);
        Test.assert(width <= layout.bannerMaxWidth);
    }
    // The warning texts keep their triangle.
    banner.setCritical(false);
    banner.text = "High heart rate at rest";
    Test.assert(banner.showsIcon(fixture.dc));
    fixture.finish();
    return true;
}
