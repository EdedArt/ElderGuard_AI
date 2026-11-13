import Toybox.Lang;

// Why help was called: the 'manual' / 'fall' reasons of the web app (SosReason in wear-app).
enum SosReason {
    // The SOS button, held for 2 seconds.
    SOS_REASON_MANUAL,
    // A fall countdown that nobody cancelled.
    SOS_REASON_FALL,
}

// Port of src/core/sosController.js: starts and ends an SOS. Activating switches
// deviceStatus.mode to MODE_SOS in the store and remembers why; cancelling switches it back to
// MODE_MONITORING. The screens react to that mode, like the web app's SOS screen.
class SosController {
    private var _store as TelemetryStore;
    private var _reason as SosReason = SOS_REASON_MANUAL;

    function initialize(store as TelemetryStore) {
        _store = store;
    }

    function isActive() as Boolean {
        return _store.getState().deviceStatus.mode == MODE_SOS;
    }

    // Why the SOS in progress started, or null when none is in progress.
    function activeReason() as SosReason or Null {
        return isActive() ? _reason : null;
    }

    // Calls for help. Activating while an SOS is already active changes nothing, not even the
    // reason.
    function activate(reason as SosReason) as Void {
        if (isActive()) {
            return;
        }
        _reason = reason;
        _store.setMode(MODE_SOS);
    }

    function cancel() as Void {
        _store.setMode(MODE_MONITORING);
    }
}
