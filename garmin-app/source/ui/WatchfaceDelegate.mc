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
// - Holding UP opens the menu on every Garmin watch (onMenu): here it opens the language
//   screen. DOWN, or a swipe up on the screen (onNextPage), opens it too, so it can also be
//   reached by touch.
// - BACK leaves the app (the system default).
//
// Each callback only unwraps its event and calls a method that takes the key or the touch
// coordinates, which the tests call directly (Toybox events cannot be created outside the system).
class WatchfaceDelegate extends WatchUi.BehaviorDelegate {
    private var _view as WatchfaceView;
    private var _controller as WatchfaceController;
    private var _language as LanguagePreference;

    function initialize(view as WatchfaceView, controller as WatchfaceController, language as LanguagePreference) {
        BehaviorDelegate.initialize();
        _view = view;
        _controller = controller;
        _language = language;
    }

    function onMenu() as Boolean {
        LanguageMenu.open(_language);
        return true;
    }

    function onNextPage() as Boolean {
        LanguageMenu.open(_language);
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        return keyPressed(keyEvent.getKey());
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        return keyReleased(keyEvent.getKey());
    }

    function keyPressed(key as WatchUi.Key) as Boolean {
        if (key == WatchUi.KEY_ENTER) {
            _controller.sosPress();
            return true;
        }
        return false;
    }

    function keyReleased(key as WatchUi.Key) as Boolean {
        if (key == WatchUi.KEY_ENTER) {
            _controller.sosRelease();
            return true;
        }
        return false;
    }

    // START and taps also produce onSelect, before onTap. Both are handled by the other
    // callbacks, so this one lets the event through: returning true here would stop onTap.
    function onSelect() as Boolean {
        return false;
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touchHeld(clickEvent.getCoordinates());
    }

    function onRelease(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touchReleased();
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return tapped(clickEvent.getCoordinates());
    }

    function touchHeld(coordinates as [Number, Number]) as Boolean {
        if (_view.isOnSosButton(coordinates)) {
            _controller.sosPress();
            return true;
        }
        return false;
    }

    function touchReleased() as Boolean {
        if (_controller.hold.isPressed()) {
            _controller.sosRelease();
            return true;
        }
        return false;
    }

    function tapped(coordinates as [Number, Number]) as Boolean {
        if (_view.isOnSosButton(coordinates)) {
            _controller.sosTap();
            return true;
        }
        return false;
    }
}
