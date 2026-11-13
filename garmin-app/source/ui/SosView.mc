import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Full-screen red screen shown while SOS is active, like the web and Wear OS SOS screens:
// "Pidiendo ayuda…" and a large "Cancelar" button. AlertScreens opens it while
// deviceStatus.mode is MODE_SOS and closes it when the mode leaves MODE_SOS.
class SosView extends WatchUi.View {
    private var _language as LanguagePreference;
    private var _layout as WatchfaceLayout or Null;
    private var _backHint as ButtonHintArc or Null;

    function initialize(language as LanguagePreference) {
        View.initialize();
        _language = language;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var layout = new WatchfaceLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        // White on the red screen, next to BACK: the button that cancels.
        _backHint = new ButtonHintArc(layout, layout.backKeyAngle, WatchColors.ON_DANGER);
    }

    // True if a touch at these screen coordinates is on the cancel button.
    function isOnCancelButton(coordinates as [Number, Number]) as Boolean {
        var layout = _layout;
        if (layout == null) {
            return false;
        }
        var x = coordinates[0];
        var y = coordinates[1];
        // The button plus a margin, for unsteady hands.
        var margin = layout.scale(12);
        return x >= layout.centerX - layout.cancelWidth / 2 - margin && x <= layout.centerX + layout.cancelWidth / 2 + margin
            && y >= layout.cancelY - layout.cancelHeight / 2 - margin && y <= layout.cancelY + layout.cancelHeight / 2 + margin;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var layout = _layout;
        var backHint = _backHint;
        if (layout == null || backHint == null) {
            return;
        }
        dc.setColor(WatchColors.ON_DANGER, WatchColors.DANGER);
        dc.clear();
        dc.setAntiAlias(true);

        // The largest font in which the title fits the width of the screen at its row.
        var title = _language.text(Rez.Strings.SosActive, Rez.Strings.SosActiveEn);
        var fonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>;
        var font = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(title, fonts[i]) <= layout.sosTitleMaxWidth) {
                font = fonts[i];
                break;
            }
        }
        dc.drawText(layout.centerX, layout.sosTitleY, font, title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Cancel: white pill with red text, inverted from the screen so the only action stands out.
        var left = layout.centerX - layout.cancelWidth / 2;
        var top = layout.cancelY - layout.cancelHeight / 2;
        dc.setColor(WatchColors.ON_DANGER, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, layout.cancelWidth, layout.cancelHeight, layout.cancelHeight / 2);
        dc.setColor(WatchColors.DANGER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, layout.cancelY, Graphics.FONT_MEDIUM,
            _language.text(Rez.Strings.SosCancel, Rez.Strings.SosCancelEn), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        backHint.draw(dc);
    }
}

// Input of the SOS screen: tapping the cancel button or pressing BACK cancels the SOS. Pressing
// BACK is how every Garmin screen is left or cancelled. START does nothing here, so the hold that
// activated the SOS cannot affect this screen when the button is released.
class SosDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SosView;
    private var _sos as SosController;

    function initialize(view as SosView, sos as SosController) {
        BehaviorDelegate.initialize();
        _view = view;
        _sos = sos;
    }

    function onBack() as Boolean {
        _sos.cancel();
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return tapped(clickEvent.getCoordinates());
    }

    // Everything else is swallowed, so nothing leaves the SOS screen by accident. BACK goes
    // through, so the system turns it into onBack().
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        return swallows(keyEvent.getKey());
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        return swallows(keyEvent.getKey());
    }

    // The callbacks unwrap their events and call these, which the tests call directly.
    function tapped(coordinates as [Number, Number]) as Boolean {
        if (_view.isOnCancelButton(coordinates)) {
            _sos.cancel();
        }
        return true;
    }

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
