import Toybox.Lang;
import Toybox.Test;

// The SOS hold logic, like tests/longPress.test.js and SosButtonTest.kt: times are passed in, so
// the 2-second hold is checked without waiting.

(:test)
function sos_doesNotCompleteBeforeTwoSeconds(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.press(1000);
    Test.assert(!hold.update(1000 + SosConfig.HOLD_DURATION_MS - 1));
    Test.assert(hold.isPressed());
    return true;
}

(:test)
function sos_completesExactlyOnceAtTwoSeconds(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.press(1000);
    Test.assert(hold.update(1000 + SosConfig.HOLD_DURATION_MS));
    Test.assert(!hold.update(1000 + SosConfig.HOLD_DURATION_MS + 500));
    // The press is over, even though the button may still be down.
    Test.assert(!hold.isPressed());
    return true;
}

(:test)
function sos_reportsTheProgressOfTheHold(logger as Logger) as Boolean {
    var hold = new SosHold();
    Test.assertEqual(hold.progress(0), 0.0);
    hold.press(1000);
    Test.assertEqual(hold.progress(1000), 0.0);
    Test.assertEqual(hold.progress(2000), 0.5);
    Test.assertEqual(hold.progress(5000), 1.0);
    return true;
}

(:test)
function sos_aShortPressShowsTheHintForTwoSeconds(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.press(1000);
    hold.release(1500);
    Test.assert(!hold.isPressed());
    Test.assertEqual(hold.progress(1500), 0.0);
    Test.assert(hold.isHintVisible(1500));
    Test.assert(hold.isHintVisible(1500 + SosConfig.HOLD_HINT_DURATION_MS - 1));
    Test.assert(!hold.isHintVisible(1500 + SosConfig.HOLD_HINT_DURATION_MS));
    return true;
}

(:test)
function sos_aTapShowsTheHint(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.tap(1000);
    Test.assert(hold.isHintVisible(1100));
    Test.assert(!hold.isPressed());
    return true;
}

(:test)
function sos_theReleaseAfterACompletedHoldShowsNoHint(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.press(1000);
    Test.assert(hold.update(3000));
    hold.release(3200);
    return !hold.isHintVisible(3200);
}

(:test)
function sos_aNewPressHidesTheHintAndStartsOver(logger as Logger) as Boolean {
    var hold = new SosHold();
    hold.press(1000);
    hold.release(1200);
    hold.press(1500);
    Test.assert(!hold.isHintVisible(1500));
    // A repeated press while held (START and touch together) does not restart the hold.
    hold.press(2500);
    Test.assert(hold.update(1500 + SosConfig.HOLD_DURATION_MS));
    return true;
}

(:test)
function sos_animatesOnlyWhilePressedOrShowingTheHint(logger as Logger) as Boolean {
    var hold = new SosHold();
    Test.assert(!hold.isAnimating(0));
    hold.press(1000);
    Test.assert(hold.isAnimating(1000));
    hold.release(1200);
    Test.assert(hold.isAnimating(1300));
    Test.assert(!hold.isAnimating(1200 + SosConfig.HOLD_HINT_DURATION_MS));
    return true;
}

(:test)
function sos_controllerSwitchesTheDeviceMode(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var sos = new SosController(store);
    Test.assert(!sos.isActive());
    sos.activate();
    Test.assert(store.getState().deviceStatus.mode == MODE_SOS);
    Test.assert(sos.isActive());
    sos.cancel();
    Test.assert(store.getState().deviceStatus.mode == MODE_MONITORING);
    return !sos.isActive();
}

(:test)
function sos_controllerKeepsTheRestOfTheDeviceStatus(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var next = store.getState();
    next.deviceStatus = new DeviceStatus(MODE_MONITORING, 1234l, HEALTH_ALERT_HIGH_HEART_RATE);
    store.update(next);
    new SosController(store).activate();
    var status = store.getState().deviceStatus;
    Test.assert(status.lastUpdate == 1234l);
    return status.healthAlert == HEALTH_ALERT_HIGH_HEART_RATE;
}

(:test)
function sos_activatingTwiceNotifiesOnce(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());
    var sos = new SosController(store);
    sos.activate();
    sos.activate();
    return recorder.states.size() == 1;
}
