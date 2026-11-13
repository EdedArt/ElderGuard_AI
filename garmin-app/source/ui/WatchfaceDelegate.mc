import Toybox.Lang;
import Toybox.WatchUi;

// Input of the watchface. The fr165 has a touch screen and five buttons; apps receive four of
// them (LIGHT is reserved by the system):
// - START (KEY_ENTER): onKeyPressed when it goes down and onKeyReleased when it comes up, so a
//   hold can be timed exactly. It is the main way to call for help, like the START/STOP button
//   that starts and confirms things everywhere on Garmin watches, and it works with wet hands
//   or gloves.
// - The SOS circle on screen: a still finger produces no drag events; the system sends onHold
//   about a second after the touch, and onRelease when it lifts. A quick tap sends onTap.
// - BACK leaves the app (the system default); UP and DOWN are used by later commits.
class WatchfaceDelegate extends WatchUi.BehaviorDelegate {
    private var _view as WatchfaceView;
    private var _controller as WatchfaceController;

    function initialize(view as WatchfaceView, controller as WatchfaceController) {
        BehaviorDelegate.initialize();
        _view = view;
        _controller = controller;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _controller.sosPress();
            return true;
        }
        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _controller.sosRelease();
            return true;
        }
        return false;
    }

    // START and taps also produce onSelect; both are already handled above and below.
    function onSelect() as Boolean {
        return true;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (_view.isOnSosButton(clickEvent.getCoordinates())) {
            _controller.sosPress();
            return true;
        }
        return false;
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (_controller.hold.isPressed()) {
            _controller.sosRelease();
            return true;
        }
        return false;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (_view.isOnSosButton(clickEvent.getCoordinates())) {
            _controller.sosTap();
            return true;
        }
        return false;
    }
}
