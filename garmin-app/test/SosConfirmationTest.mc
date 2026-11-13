import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// The alert confirmation on the SOS screen, like the confirmation cases of
// FallCountdownScreenTest.kt and AlertLocationTest.kt in wear-app.

(:test)
class SosScreenFixture {
    var device as DeviceHarness = new DeviceHarness();
    var language as LanguagePreference;
    var view as SosView;
    var delegate as SosDelegate;
    var layout as WatchfaceLayout = new WatchfaceLayout(390, 390);
    var dc as Graphics.Dc;

    function initialize(languageTag as String or Null) {
        language = new LanguagePreference(new MemoryLanguageStorage(languageTag));
        view = new SosView(language, device.alerts);
        delegate = new SosDelegate(view, device.sos);
        dc = (Graphics.createBufferedBitmap({:width => 390, :height => 390}).get() as Graphics.BufferedBitmap).getDc();
        view.onLayout(dc);
        device.gps = new Gps(4.6097d, -74.0817d, 3.0d, true);
        device.second();
    }

    function render() as Void {
        view.onUpdate(dc);
    }
}

(:test)
function sosConfirmation_formatsCoordinatesWithFiveDecimalsAndADot(logger as Logger) as Boolean {
    Test.assertEqual(SosView.formatCoordinate(4.6097d), "4.60970");
    Test.assertEqual(SosView.formatCoordinate(-74.0817d), "-74.08170");
    Test.assertEqual(SosView.formatCoordinate(4.612345678d), "4.61235");
    return true;
}

(:test)
function sosConfirmation_aFallSosShowsTheNotifiedContactsAndTheGpsCoordinates(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    f.device.simulateFall();
    f.device.seconds(FallDetectionConfig.COUNTDOWN_SECONDS);
    Test.assert(f.device.sos.activeReason() == SOS_REASON_FALL);
    f.render();
    Test.assert(f.view.confirming);
    Test.assertEqual(f.view.notified, "Avisados (simulado)");
    Test.assertEqual(f.view.contactNames.toString(), ["Ana Ejemplo", "Luis Ejemplo", "Dra. Prueba"].toString());
    Test.assertEqual(f.view.locationLabel, "GPS");
    Test.assertEqual(f.view.coordinates, "4.60970, -74.08170");
    f.device.finish();
    return true;
}

(:test)
function sosConfirmation_aManualSosShowsTheSameConfirmation(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.render();
    Test.assert(f.view.confirming);
    Test.assertEqual(f.view.contactNames.size(), 3);
    Test.assertEqual(f.view.coordinates, "4.60970, -74.08170");
    return true;
}

(:test)
function sosConfirmation_withoutSignalItGivesTheLastPosition(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    f.device.gps = new Gps(4.61001d, -74.08002d, 3.0d, false);
    f.device.second();
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.render();
    Test.assertEqual(f.view.locationLabel, "Última posición");
    Test.assertEqual(f.view.coordinates, "4.61001, -74.08002");
    return true;
}

(:test)
function sosConfirmation_followsTheLanguage(logger as Logger) as Boolean {
    var f = new SosScreenFixture("en");
    f.device.gps = new Gps(4.6097d, -74.0817d, 3.0d, false);
    f.device.second();
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.render();
    Test.assertEqual(f.view.notified, "Notified (mock)");
    Test.assertEqual(f.view.locationLabel, "Last position");
    // Names and coordinates are the same in both languages.
    Test.assertEqual(f.view.contactNames[0], "Ana Ejemplo");
    Test.assertEqual(f.view.coordinates, "4.60970, -74.08170");
    return true;
}

(:test)
function sosConfirmation_theNextSosDoesNotShowThePreviousConfirmation(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.device.sos.cancel();
    f.render();
    Test.assert(!f.view.confirming);
    // A new SOS records its own alert, with the position of its own moment.
    f.device.gps = new Gps(4.6100d, -74.0800d, 3.0d, true);
    f.device.second();
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.render();
    Test.assertEqual(f.view.coordinates, "4.61000, -74.08000");
    return true;
}

(:test)
function sosConfirmation_theCancelButtonWorksWhereItIsDrawn(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    f.device.sos.activate(SOS_REASON_MANUAL);
    f.render();
    // The coordinates line, above the button, is not the button.
    f.delegate.tapped([f.layout.centerX, f.layout.coordinatesY] as [Number, Number]);
    Test.assert(f.device.sos.isActive());
    f.delegate.tapped([f.layout.centerX, f.layout.confirmCancelY] as [Number, Number]);
    Test.assert(!f.device.sos.isActive());
    // BACK still cancels.
    f.device.sos.activate(SOS_REASON_MANUAL);
    Test.assert(f.delegate.onBack());
    Test.assert(!f.device.sos.isActive());
    return true;
}

(:test)
function sosConfirmation_everyLineFitsTheRoundScreenWithoutOverlapping(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    var layout = f.layout;
    var dc = f.dc;
    var radius = layout.sosSafeRadius;
    // The longest text of each row in either language, its fonts and its row.
    var rows = [
        ["Pidiendo ayuda…", layout.sosTitleFonts, layout.confirmTitleY],
        ["Calling for help…", layout.sosTitleFonts, layout.confirmTitleY],
        ["Avisados (simulado)", [layout.detailFont], layout.notifiedY],
        ["Luis Ejemplo", layout.contactFonts, layout.contactsY],
        ["Ana Ejemplo", layout.contactFonts, layout.contactsY + layout.contactStep],
        ["Dra. Prueba", layout.contactFonts, layout.contactsY + 2 * layout.contactStep],
        ["Última posición", [layout.detailFont], layout.locationLabelY],
        ["-74.08170, -174.08170", layout.contactFonts, layout.coordinatesY],
    ];
    var previousBottom = 0;
    for (var i = 0; i < rows.size(); i++) {
        var row = rows[i] as Array;
        var text = row[0] as String;
        var fonts = row[1] as Array<Graphics.FontType>;
        var y = row[2] as Number;
        var font = layout.fittingFont(dc, text, fonts, y, radius);
        var width = dc.getTextWidthInPixels(text, font);
        var half = Graphics.getFontAscent(font) / 2;
        logger.debug(text + ": " + width + " px of " + layout.widthInCircle(y, half, radius) + " at y " + y);
        Test.assertMessage(width <= layout.widthInCircle(y, half, radius), text + " leaves the screen");
        // Rows of the same y (both titles) share their place; the next row starts below.
        if (i != 1) {
            Test.assertMessage(y - half >= previousBottom - layout.scale(2), text + " overlaps the row above");
        }
        previousBottom = y + half;
    }
    // The button below the last row, and its rounded ends inside the screen.
    var top = layout.confirmCancelY - layout.confirmCancelHeight / 2;
    Test.assert(top >= previousBottom);
    var capRadius = layout.confirmCancelHeight / 2;
    var capX = layout.confirmCancelWidth / 2 - capRadius;
    var capY = layout.confirmCancelY - layout.height / 2;
    Test.assert(Math.sqrt(capX * capX + capY * capY) + capRadius <= radius);
    // The label fits the button in both languages.
    var labels = ["Cancelar", "Cancel"];
    for (var i = 0; i < labels.size(); i++) {
        var label = labels[i] as String;
        var font = layout.fontForWidth(dc, label, layout.titleFonts, layout.confirmCancelWidth - capRadius);
        Test.assert(dc.getTextWidthInPixels(label, font) <= layout.confirmCancelWidth - capRadius);
    }
    return true;
}

(:test)
function sosConfirmation_drawsInBothLanguagesWithAndWithoutSignal(logger as Logger) as Boolean {
    var tags = [null, "en"];
    for (var i = 0; i < tags.size(); i++) {
        for (var signal = 0; signal < 2; signal++) {
            var f = new SosScreenFixture(tags[i] as String or Null);
            f.device.gps = new Gps(-33.44889d, -170.66926d, 3.0d, signal == 1);
            f.device.second();
            f.device.sos.activate(SOS_REASON_MANUAL);
            f.render();
            Test.assert(f.view.confirming);
        }
    }
    return true;
}
