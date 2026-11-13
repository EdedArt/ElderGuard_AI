import Toybox.Lang;

// Port of src/core/fallMonitor.js (FallMonitor.kt and FallDetector.feedFrom in wear-app): feeds
// the fall detector from the telemetry store, so every engine tick is a reading, and runs the
// alert that follows a detection.
//
// - Every store notification counts as a reading, not only those that list the accelerometer: a
//   body lying perfectly still gives the same reading tick after tick, and the detector needs
//   those readings to see the time go by. Each tick writes a new battery level and lastUpdate,
//   so the store notifies on every tick.
// - Readings count only while the watch is monitoring. In any other mode the detector is reset,
//   otherwise a fall in progress would resume, with a gap in its timing, after the alert ends.
// - The first reading after coming back to monitoring is skipped: it still dates from the alert.
//
// A confirmed fall switches the watch to MODE_FALL_COUNTDOWN and starts a countdown of
// FallDetectionConfig.COUNTDOWN_SECONDS. cancel() ("Estoy bien") stops it and goes back to
// monitoring. If nobody cancels it, reaching zero calls for help: an SOS with SOS_REASON_FALL.
// Leaving the countdown mode any other way stops the countdown too.
class FallMonitor {
    private var _store as TelemetryStore;
    private var _sos as SosController;
    private var _detector as FallDetector;
    private var _clock as Clock;
    private var _listener as TelemetryListener;
    private var _previousMode as DeviceMode;
    private var _countdown as Countdown;
    private var _tickListener as CountdownTickListener or Null = null;

    function initialize(store as TelemetryStore, sos as SosController, detector as FallDetector, clock as Clock) {
        _store = store;
        _sos = sos;
        _detector = detector;
        _clock = clock;
        _previousMode = store.getState().deviceStatus.mode;
        _countdown = new Countdown(method(:onCountdownTick), method(:onCountdownComplete));
        _listener = method(:onTelemetryChanged) as TelemetryListener;
        store.register(_listener);
    }

    function getDetectorState() as FallState {
        return _detector.getState();
    }

    // Seconds left in the fall countdown, or null when none is running.
    function remainingSeconds() as Number or Null {
        return _countdown.remaining();
    }

    // The countdown itself, so tests can advance it with tick() instead of waiting for its timer.
    function countdown() as Countdown {
        return _countdown;
    }

    // Who hears each second of the countdown (the alert screens, which vibrate and redraw), or
    // null for nobody.
    function setTickListener(listener as CountdownTickListener or Null) as Void {
        _tickListener = listener;
    }

    // Forgets a sequence in progress. An alert already raised is not affected.
    function resetDetector() as Void {
        _detector.reset();
    }

    // "Estoy bien": stops the countdown and goes back to monitoring. Only acts during a countdown.
    function cancel() as Void {
        if (_store.getState().deviceStatus.mode != MODE_FALL_COUNTDOWN) {
            return;
        }
        _countdown.cancel();
        _detector.reset();
        _store.setMode(MODE_MONITORING);
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        var mode = state.deviceStatus.mode;
        var wasMonitoring = _previousMode == MODE_MONITORING;
        _previousMode = mode;
        if (mode != MODE_FALL_COUNTDOWN) {
            _countdown.cancel();
        }
        if (mode != MODE_MONITORING) {
            _detector.reset();
        } else if (wasMonitoring && _detector.process(state.accelerometer, _clock.now())) {
            onFallConfirmed();
        }
    }

    function onCountdownTick(remaining as Number) as Void {
        var listener = _tickListener;
        if (listener != null) {
            listener.invoke(remaining);
        }
    }

    // Nobody answered: call for help. The SOS screen replaces the countdown.
    function onCountdownComplete() as Void {
        _sos.activate(SOS_REASON_FALL);
    }

    private function onFallConfirmed() as Void {
        _store.setMode(MODE_FALL_COUNTDOWN);
        _countdown.start(FallDetectionConfig.COUNTDOWN_SECONDS);
    }
}
