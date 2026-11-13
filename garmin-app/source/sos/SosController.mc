import Toybox.Lang;

// Starts and ends an SOS, the part of src/core/sosController.js this phase needs: activating
// switches deviceStatus.mode to MODE_SOS in the store, and cancelling switches it back to
// MODE_MONITORING. The screens react to that mode, like the web app's SOS screen.
class SosController {
    private var _store as TelemetryStore;

    function initialize(store as TelemetryStore) {
        _store = store;
    }

    function isActive() as Boolean {
        return _store.getState().deviceStatus.mode == MODE_SOS;
    }

    // Activating while an SOS is already active changes nothing.
    function activate() as Void {
        setMode(MODE_SOS);
    }

    function cancel() as Void {
        setMode(MODE_MONITORING);
    }

    private function setMode(mode as DeviceMode) as Void {
        var next = _store.getState();
        var status = next.deviceStatus;
        next.deviceStatus = new DeviceStatus(mode, status.lastUpdate, status.healthAlert);
        _store.update(next);
    }
}
