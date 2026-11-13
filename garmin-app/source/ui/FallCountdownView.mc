import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Full-screen alert after a detected fall, like the fall overlays of the web and Wear OS apps:
// "¿Te caíste?", the seconds left in large digits, a ring that drains with them and a large
// "ESTOY BIEN" button. Amber with black text at first, red with white text in the last
// FallDetectionConfig.URGENT_SECONDS.
//
// It only draws: AlertScreens opens and closes it with the device mode and, on every second of
// the countdown, vibrates and asks for a redraw. The ring drains one step per second, with the
// number, rather than continuously: that would mean redrawing many times a second.
class FallCountdownView extends WatchUi.View {
    private var _fall as FallMonitor;
    private var _language as LanguagePreference;
    private var _layout as WatchfaceLayout or Null;
    private var _backHint as ButtonHintArc or Null;

    // What the last onUpdate() drew, for the tests (Run No Evil cannot read pixels).
    var seconds as Number = 0;
    var urgent as Boolean = false;
    var ringDegrees as Number = 0;
    var question as String = "";
    var cancelLabel as String = "";

    function initialize(fall as FallMonitor, language as LanguagePreference) {
        View.initialize();
        _fall = fall;
        _language = language;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var layout = new WatchfaceLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        // At the edge next to BACK, the button that answers "Estoy bien".
        _backHint = new ButtonHintArc(layout, layout.backKeyAngle, WatchColors.ON_WARNING);
    }

    // True if a touch at these screen coordinates is on the "Estoy bien" button.
    function isOnCancelButton(coordinates as [Number, Number]) as Boolean {
        var layout = _layout;
        return layout != null
            && layout.isOnButton(coordinates[0], coordinates[1], layout.fallButtonY, layout.fallButtonWidth, layout.fallButtonHeight);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var layout = _layout;
        var backHint = _backHint;
        if (layout == null || backHint == null) {
            return;
        }
        var remaining = _fall.remainingSeconds();
        seconds = remaining != null ? remaining : 0;
        urgent = seconds <= FallDetectionConfig.URGENT_SECONDS;
        ringDegrees = seconds * 360 / FallDetectionConfig.COUNTDOWN_SECONDS;
        question = _language.text(Rez.Strings.FallQuestion, Rez.Strings.FallQuestionEn);
        cancelLabel = _language.text(Rez.Strings.FallCancel, Rez.Strings.FallCancelEn);

        var surface = urgent ? WatchColors.DANGER : WatchColors.WARNING;
        var content = urgent ? WatchColors.ON_DANGER : WatchColors.ON_WARNING;
        dc.setColor(content, surface);
        dc.clear();
        dc.setAntiAlias(true);

        drawRing(dc, layout, content);

        var centered = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(content, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, layout.fallTitleY,
            layout.fittingFont(dc, question, layout.titleFonts, layout.fallTitleY, layout.fallContentRadius), question, centered);
        dc.drawText(layout.centerX, layout.fallSecondsY, layout.fallSecondsFont, seconds.toString(), centered);

        // "Estoy bien": black with a white outline and white text, as in the other apps, so it
        // stands out on both amber and red.
        var width = layout.fallButtonWidth;
        var height = layout.fallButtonHeight;
        var left = layout.centerX - width / 2;
        var top = layout.fallButtonY - height / 2;
        dc.setColor(WatchColors.BACKGROUND, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, width, height, height / 2);
        dc.setColor(WatchColors.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(layout.scale(3));
        dc.drawRoundedRectangle(left, top, width, height, height / 2);
        // The label stays clear of the rounded ends of the button.
        dc.drawText(layout.centerX, layout.fallButtonY, layout.fontForWidth(dc, cancelLabel, layout.titleFonts, width - height / 2),
            cancelLabel, centered);

        backHint.color = content;
        backHint.draw(dc);
    }

    // A thin full circle as the track and, over it, a thick arc for the time left, from
    // 12 o'clock clockwise.
    private function drawRing(dc as Graphics.Dc, layout as WatchfaceLayout, color as Number) as Void {
        var cy = layout.height / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(layout.scale(2));
        dc.drawCircle(layout.centerX, cy, layout.fallRingRadius);
        if (ringDegrees <= 0) {
            return;
        }
        dc.setPenWidth(layout.fallRingWidth);
        if (ringDegrees >= 360) {
            dc.drawCircle(layout.centerX, cy, layout.fallRingRadius);
        } else {
            dc.drawArc(layout.centerX, cy, layout.fallRingRadius, Graphics.ARC_CLOCKWISE, 90, 90 - ringDegrees);
        }
    }
}

// Input of the fall countdown. "Estoy bien" must be quick and certain, since the person may have
// fallen and has only 10 seconds:
// - BACK, a single quick press. BACK cancels on every Garmin screen and already cancels the SOS
//   screen. START is deliberately not used: it is the SOS button on the watchface, so someone
//   who fell and presses it to ask for help must never cancel the alert by doing so.
// - The on-screen button, with a tap, or with a finger kept on it: a still finger produces
//   onHold (about a second after the touch) and no onTap, so both count.
// No hold is required: a second hold would eat into the 10 seconds, and the touch hold only
// starts registering after about a second.
// Everything else is swallowed. Swipes too: on touch watches a swipe right acts as BACK, and a
// sleeve brushing the screen must not cancel the alert.
class FallCountdownDelegate extends WatchUi.BehaviorDelegate {
    private var _view as FallCountdownView;
    private var _fall as FallMonitor;

    function initialize(view as FallCountdownView, fall as FallMonitor) {
        BehaviorDelegate.initialize();
        _view = view;
        _fall = fall;
    }

    function onBack() as Boolean {
        _fall.cancel();
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touched(clickEvent.getCoordinates());
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        return touched(clickEvent.getCoordinates());
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        return swallows(keyEvent.getKey());
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        return swallows(keyEvent.getKey());
    }

    // The callbacks unwrap their events and call these, which the tests call directly.
    function touched(coordinates as [Number, Number]) as Boolean {
        if (_view.isOnCancelButton(coordinates)) {
            _fall.cancel();
        }
        return true;
    }

    // BACK goes through, so the system turns it into onBack().
    function swallows(key as WatchUi.Key) as Boolean {
        return key != WatchUi.KEY_ESC;
    }

    // A tap produces onSelect before onTap; returning true here would stop onTap.
    function onSelect() as Boolean {
        return false;
    }

    function onMenu() as Boolean {
        return true;
    }

    function onNextPage() as Boolean {
        return true;
    }

    function onPreviousPage() as Boolean {
        return true;
    }
}
