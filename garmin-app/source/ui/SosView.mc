import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Full-screen red screen shown while SOS is active, like the web and Wear OS SOS screens:
// "Pidiendo ayuda…", the confirmation of the alert sent (who was notified, as a mock, and the
// GPS coordinates) and a large "Cancelar" button. AlertScreens opens it while
// deviceStatus.mode is MODE_SOS and closes it when the mode leaves MODE_SOS.
//
// Wear OS scrolls the three parts; here they fit on one screen, each line in the largest font
// that fits the round screen at its row (WatchfaceLayout.fittingFont), so nothing needs scrolling.
class SosView extends WatchUi.View {
    private var _language as LanguagePreference;
    private var _alerts as AlertDispatcher;
    private var _layout as WatchfaceLayout or Null;
    private var _backHint as ButtonHintArc or Null;

    // What the last onUpdate() drew, for the tests (Run No Evil cannot read pixels).
    var confirming as Boolean = false;
    var notified as String = "";
    var contactNames as Array<String> = [] as Array<String>;
    var locationLabel as String = "";
    var coordinates as String = "";

    function initialize(language as LanguagePreference, alerts as AlertDispatcher) {
        View.initialize();
        _language = language;
        _alerts = alerts;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var layout = new WatchfaceLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        // White on the red screen, next to BACK: the button that cancels.
        _backHint = new ButtonHintArc(layout, layout.backKeyAngle, WatchColors.ON_DANGER);
    }

    // A coordinate with 5 decimals (about 1 m), like toFixed(5) in the web app; always with a dot.
    static function formatCoordinate(degrees as Double) as String {
        return degrees.format("%.5f");
    }

    // True if a touch at these screen coordinates is on the cancel button, wherever it is drawn.
    function isOnCancelButton(coordinates as [Number, Number]) as Boolean {
        var layout = _layout;
        if (layout == null) {
            return false;
        }
        var x = coordinates[0];
        var y = coordinates[1];
        return confirming
            ? layout.isOnButton(x, y, layout.confirmCancelY, layout.confirmCancelWidth, layout.confirmCancelHeight)
            : layout.isOnButton(x, y, layout.cancelY, layout.cancelWidth, layout.cancelHeight);
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

        var alert = _alerts.sosAlert();
        confirming = alert != null;
        var title = _language.text(Rez.Strings.SosActive, Rez.Strings.SosActiveEn);
        var titleY = confirming ? layout.confirmTitleY : layout.sosTitleY;
        drawLine(dc, layout, title, layout.sosTitleFonts, titleY);

        if (alert != null) {
            drawConfirmation(dc, layout, alert);
            drawCancel(dc, layout, layout.confirmCancelY, layout.confirmCancelWidth, layout.confirmCancelHeight);
        } else {
            drawCancel(dc, layout, layout.cancelY, layout.cancelWidth, layout.cancelHeight);
        }
        backHint.draw(dc);
    }

    // "Avisados (simulado)", one contact name per line, so a name never breaks in the middle, and
    // where the alert says the person is: the GPS position, or the last one known without signal.
    private function drawConfirmation(dc as Graphics.Dc, layout as WatchfaceLayout, alert as AlertPayload) as Void {
        notified = _language.text(Rez.Strings.SosNotified, Rez.Strings.SosNotifiedEn);
        drawLine(dc, layout, notified, [layout.detailFont] as Array<Graphics.FontType>, layout.notifiedY);

        contactNames = [] as Array<String>;
        for (var i = 0; i < alert.contacts.size(); i++) {
            var name = alert.contacts[i].name;
            contactNames.add(name);
            drawLine(dc, layout, name, layout.contactFonts, layout.contactsY + i * layout.contactStep);
        }

        locationLabel = alert.gps.signal
            ? _language.text(Rez.Strings.SosLocation, Rez.Strings.SosLocationEn)
            : _language.text(Rez.Strings.SosLastLocation, Rez.Strings.SosLastLocationEn);
        coordinates = Lang.format(_language.text(Rez.Strings.SosCoordinates, Rez.Strings.SosCoordinatesEn),
            [formatCoordinate(alert.gps.lat), formatCoordinate(alert.gps.lng)]);
        drawLine(dc, layout, locationLabel, [layout.detailFont] as Array<Graphics.FontType>, layout.locationLabelY);
        drawLine(dc, layout, coordinates, layout.contactFonts, layout.coordinatesY);
    }

    // A centered line in white, in the largest of fonts that fits the round screen at row y.
    private function drawLine(dc as Graphics.Dc, layout as WatchfaceLayout, text as String, fonts as Array<Graphics.FontType>, y as Number) as Void {
        dc.setColor(WatchColors.ON_DANGER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, y, layout.fittingFont(dc, text, fonts, y, layout.sosSafeRadius), text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Cancel: white pill with red text, inverted from the screen so the only action stands out.
    private function drawCancel(dc as Graphics.Dc, layout as WatchfaceLayout, y as Number, width as Number, height as Number) as Void {
        var label = _language.text(Rez.Strings.SosCancel, Rez.Strings.SosCancelEn);
        dc.setColor(WatchColors.ON_DANGER, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(layout.centerX - width / 2, y - height / 2, width, height, height / 2);
        dc.setColor(WatchColors.DANGER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, y, layout.fontForWidth(dc, label, layout.titleFonts, width - height / 2), label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
