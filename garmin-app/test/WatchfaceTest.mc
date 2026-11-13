import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The watchface and the SOS interaction, like WatchAppTest.kt and SosButtonTest.kt in wear-app.
//
// Run No Evil cannot read pixels back, so rendering is checked three ways: the layout of every
// element (measured with the real fonts) fits the round screen; the view, drawn into an
// off-screen BufferedBitmap, fills its drawables with the right text and colors; and every
// state draws without errors. Input is checked through the delegates' key and touch methods
// (the ones their Toybox callbacks call), with the controller on a fake clock.

// A controller whose clock the test sets, so a 2-second hold takes no time.
(:test)
class FakeClockController extends WatchfaceController {
    var time as Number = 0;

    function initialize(sos as SosController) {
        WatchfaceController.initialize(sos);
    }

    function now() as Number {
        return time;
    }
}

// Everything a watchface test needs, drawn into a 390x390 off-screen bitmap like the fr165 screen.
(:test)
class WatchfaceFixture {
    var store as TelemetryStore = new TelemetryStore();
    var language as LanguagePreference;
    var sos as SosController;
    var controller as FakeClockController;
    var view as WatchfaceView;
    var alerts as AlertDispatcher;
    var delegate as WatchfaceDelegate;
    var engine as SimulationEngine;
    var demo as DemoController;
    var dc as Graphics.Dc;

    function initialize(languageTag as String or Null) {
        language = new LanguagePreference(new MemoryLanguageStorage(languageTag));
        sos = new SosController(store);
        controller = new FakeClockController(sos);
        alerts = new AlertDispatcher(store, sos, HeartRateAnomalyDetector.critical(), new FakeClock());
        view = new WatchfaceView(store, language, controller, alerts);
        engine = new SimulationEngine(store, new RandomSource());
        demo = new DemoController(new ScenarioRunner(engine, store), engine, new FallMonitor(store, sos, FallDetector.standard(), new FakeClock()));
        delegate = new WatchfaceDelegate(view, controller, language, demo);
        var bitmap = Graphics.createBufferedBitmap({:width => 390, :height => 390}).get() as Graphics.BufferedBitmap;
        dc = bitmap.getDc();
        view.onLayout(dc);
    }

    function render() as Void {
        view.onUpdate(dc);
    }

    function setBattery(level as Double) as Void {
        var next = store.getState();
        next.battery = new Battery(level, false);
        store.update(next);
    }

    function setGpsSignal(signal as Boolean) as Void {
        var next = store.getState();
        next.gps = new Gps(4.6097d, -74.0817d, 3.0d, signal);
        store.update(next);
    }

    // Always stops the controller's frame timer at the end of a test.
    function finish() as Void {
        controller.stop();
    }
}

// --- Layout ---

(:test)
function watchface_everyElementFitsTheRoundScreen(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var dc = fixture.dc;
    var layout = new WatchfaceLayout(390, 390);
    // The widest text each row can show, in either language.
    var rows = [
        // Battery icon, gap, "100 %", gap between indicators, pin, gap, "Sin GPS", as the view lays them out.
        [layout.statusY, layout.statusFont, "100 %",
            layout.scale(30) + layout.iconGap + layout.statusGap + layout.scale(16) + layout.iconGap
                + dc.getTextWidthInPixels("Sin GPS", layout.statusFont)],
        [layout.timeY, layout.timeFont, "12:59", 0],
        [layout.dateY, layout.dateFont, "mié, 30 sept", 0],
        // Heart icon, double gap, "180", gap, "LPM".
        [layout.heartRateY, layout.heartRateFont, "180",
            layout.scale(30) + 3 * layout.iconGap + dc.getTextWidthInPixels("LPM", layout.unitFont)],
        [layout.hintY, layout.hintFont, "Hold to call for help", layout.scale(28)],
    ];
    for (var i = 0; i < rows.size(); i++) {
        var row = rows[i] as Array;
        var y = row[0] as Number;
        var font = row[1] as Graphics.FontType;
        var width = dc.getTextWidthInPixels(row[2] as String, font) + (row[3] as Number);
        if (i == 1) {
            // The period label sits next to the time.
            width += layout.iconGap + dc.getTextWidthInPixels("p. m.", layout.periodFont);
        }
        // The visible glyphs: from the ascent above the center line to the descent below it.
        var half = Graphics.getFontAscent(font) / 2;
        var left = layout.centerX - width / 2;
        logger.debug("row " + i + ": " + width + " px wide at y " + y);
        Test.assertMessage(layout.fitsInCircle(left, y - half, left + width, y + half), "row " + i + " leaves the screen");
    }
    // The SOS button with its progress ring.
    // The outer edge of the ring's stroke.
    var ring = layout.sosRingRadius + layout.sosRingWidth / 2 + 1;
    Test.assertMessage(layout.inCircle(layout.centerX, layout.sosY + ring), "the SOS ring leaves the screen");
    Test.assertMessage(layout.sosY - ring > layout.heartRateY + Graphics.getFontAscent(layout.heartRateFont) / 2,
        "the SOS ring overlaps the heart rate");
    // The cancel button of the SOS screen.
    Test.assert(layout.fitsInCircle(layout.centerX - layout.cancelWidth / 2, layout.cancelY - layout.cancelHeight / 2,
        layout.centerX + layout.cancelWidth / 2, layout.cancelY + layout.cancelHeight / 2));
    fixture.finish();
    return true;
}

(:test)
function watchface_sosButtonTouchAreaCoversTheButton(logger as Logger) as Boolean {
    var layout = new WatchfaceLayout(390, 390);
    Test.assert(layout.isOnSosButton(layout.centerX, layout.sosY));
    Test.assert(layout.isOnSosButton(layout.centerX + layout.sosRadius + 5, layout.sosY));
    Test.assert(!layout.isOnSosButton(layout.centerX, layout.timeY));
    return true;
}

// --- Rendering ---

(:test)
function watchface_rendersTheTelemetryInSpanish(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    fixture.render();
    var battery = fixture.view.batteryIndicator() as BatteryIndicator;
    var gps = fixture.view.gpsIndicator() as GpsIndicator;
    var heartRate = fixture.view.heartRateIndicator() as HeartRateIndicator;
    var clock = fixture.view.clockDisplay() as ClockDisplay;
    var sosButton = fixture.view.sosButton() as SosButton;
    Test.assertEqual(battery.text, "100 %");
    Test.assertEqual(battery.color, WatchColors.SUCCESS);
    Test.assertEqual(gps.text, "GPS");
    Test.assertEqual(gps.color, WatchColors.SUCCESS);
    Test.assertEqual(heartRate.bpm, 70);
    Test.assertEqual(heartRate.unit, "LPM");
    Test.assert(clock.period.equals("a. m.") || clock.period.equals("p. m."));
    Test.assertEqual(sosButton.title, "SOS");
    Test.assertEqual(sosButton.label, "AUXILIO");
    fixture.finish();
    return true;
}

(:test)
function watchface_rendersInEnglishWhenChosen(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture("en");
    fixture.setGpsSignal(false);
    fixture.render();
    Test.assertEqual((fixture.view.batteryIndicator() as BatteryIndicator).text, "100%");
    Test.assertEqual((fixture.view.gpsIndicator() as GpsIndicator).text, "No GPS");
    Test.assertEqual((fixture.view.heartRateIndicator() as HeartRateIndicator).unit, "BPM");
    Test.assertEqual((fixture.view.sosButton() as SosButton).label, "HELP");
    var period = (fixture.view.clockDisplay() as ClockDisplay).period;
    Test.assert(period.equals("AM") || period.equals("PM"));
    fixture.finish();
    return true;
}

(:test)
function watchface_colorsTheStatusIndicators(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    fixture.setBattery(20.4d);
    fixture.setGpsSignal(false);
    fixture.render();
    var battery = fixture.view.batteryIndicator() as BatteryIndicator;
    var gps = fixture.view.gpsIndicator() as GpsIndicator;
    Test.assertEqual(battery.text, "20 %");
    Test.assertEqual(battery.color, WatchColors.WARNING);
    Test.assertEqual(gps.text, "Sin GPS");
    Test.assertEqual(gps.color, WatchColors.WARNING);
    fixture.setBattery(10.0d);
    fixture.render();
    Test.assertEqual(battery.color, WatchColors.DANGER_TEXT);
    fixture.finish();
    return true;
}

(:test)
function watchface_drawsEveryStateWithoutErrors(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var levels = [100.0d, 55.5d, 20.0d, 9.0d, 0.0d];
    for (var i = 0; i < levels.size(); i++) {
        fixture.setBattery(levels[i]);
        fixture.setGpsSignal(i % 2 == 0);
        fixture.render();
    }
    // Pressed with the ring at three quarters, then the hint after a short press.
    fixture.controller.time = 1000;
    fixture.controller.sosPress();
    fixture.controller.time = 2500;
    fixture.render();
    Test.assertEqual((fixture.view.sosButton() as SosButton).progress, 0.75);
    Test.assert((fixture.view.sosButton() as SosButton).pressed);
    fixture.controller.sosRelease();
    fixture.render();
    Test.assert(!(fixture.view.sosButton() as SosButton).pressed);
    fixture.finish();
    return true;
}

(:test)
function sosScreen_drawsInBothLanguagesWithoutErrors(logger as Logger) as Boolean {
    var tags = [null, "en"];
    for (var i = 0; i < tags.size(); i++) {
        var fixture = new WatchfaceFixture(tags[i] as String or Null);
        var view = new SosView(fixture.language, fixture.alerts);
        view.onLayout(fixture.dc);
        view.onUpdate(fixture.dc);
        fixture.finish();
    }
    return true;
}

// --- SOS interaction ---

(:test)
function interaction_holdingStartForTwoSecondsActivatesSos(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    fixture.controller.time = 5000;
    Test.assert(fixture.delegate.keyPressed(WatchUi.KEY_ENTER));
    fixture.controller.time = 5000 + SosConfig.HOLD_DURATION_MS - 100;
    fixture.controller.onFrame();
    Test.assert(!fixture.sos.isActive());
    fixture.controller.time = 5000 + SosConfig.HOLD_DURATION_MS;
    fixture.controller.onFrame();
    Test.assert(fixture.sos.isActive());
    // Releasing START afterwards neither cancels nor shows the hint.
    fixture.controller.time = 7500;
    fixture.delegate.keyReleased(WatchUi.KEY_ENTER);
    Test.assert(fixture.sos.isActive());
    Test.assert(!fixture.controller.hold.isHintVisible(7500));
    fixture.finish();
    return true;
}

(:test)
function interaction_aShortStartPressShowsTheHintAndDoesNotActivate(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    fixture.controller.time = 1000;
    fixture.delegate.keyPressed(WatchUi.KEY_ENTER);
    fixture.controller.time = 1800;
    fixture.delegate.keyReleased(WatchUi.KEY_ENTER);
    Test.assert(!fixture.sos.isActive());
    Test.assert(fixture.controller.hold.isHintVisible(1800));
    fixture.finish();
    return true;
}

(:test)
function interaction_holdingAFingerOnTheButtonActivatesSos(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var layout = new WatchfaceLayout(390, 390);
    var onButton = [layout.centerX, layout.sosY] as [Number, Number];
    fixture.controller.time = 0;
    Test.assert(fixture.delegate.touchHeld(onButton));
    fixture.controller.time = SosConfig.HOLD_DURATION_MS;
    fixture.controller.onFrame();
    Test.assert(fixture.sos.isActive());
    fixture.finish();
    return true;
}

(:test)
function interaction_touchesAwayFromTheButtonAreIgnored(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var layout = new WatchfaceLayout(390, 390);
    var onClock = [layout.centerX, layout.timeY] as [Number, Number];
    Test.assert(!fixture.delegate.touchHeld(onClock));
    Test.assert(!fixture.delegate.tapped(onClock));
    Test.assert(!fixture.controller.hold.isPressed());
    Test.assert(!fixture.controller.hold.isHintVisible(0));
    // A tap on the button only shows the hint.
    var onButton = [layout.centerX, layout.sosY] as [Number, Number];
    fixture.controller.time = 100;
    Test.assert(fixture.delegate.tapped(onButton));
    Test.assert(fixture.controller.hold.isHintVisible(100));
    Test.assert(!fixture.sos.isActive());
    fixture.finish();
    return true;
}

(:test)
function interaction_otherButtonsDoNotTouchSos(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var keys = [WatchUi.KEY_UP, WatchUi.KEY_DOWN, WatchUi.KEY_ESC];
    for (var i = 0; i < keys.size(); i++) {
        Test.assert(!fixture.delegate.keyPressed(keys[i] as WatchUi.Key));
    }
    Test.assert(!fixture.controller.hold.isPressed());
    fixture.finish();
    return true;
}

(:test)
function interaction_theSosScreenCancelsWithBackOrTheCancelButton(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var view = new SosView(fixture.language, fixture.alerts);
    view.onLayout(fixture.dc);
    var delegate = new SosDelegate(view, fixture.sos);
    var layout = new WatchfaceLayout(390, 390);

    fixture.sos.activate(SOS_REASON_MANUAL);
    // START (still held from the activation) and taps outside the button change nothing.
    Test.assert(delegate.swallows(WatchUi.KEY_ENTER));
    delegate.tapped([layout.centerX, layout.sosTitleY] as [Number, Number]);
    Test.assert(fixture.sos.isActive());

    delegate.tapped([layout.centerX, layout.cancelY] as [Number, Number]);
    Test.assert(!fixture.sos.isActive());

    fixture.sos.activate(SOS_REASON_MANUAL);
    Test.assert(delegate.onBack());
    Test.assert(!fixture.sos.isActive());
    fixture.finish();
    return true;
}

// --- Heart rate banner ---

(:test)
function banner_showsWhileAHeartRateWarningLastsInPlaceOfTheDate(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    fixture.render();
    var banner = fixture.view.heartRateBanner() as HeartRateBanner;
    var clock = fixture.view.clockDisplay() as ClockDisplay;
    Test.assert(!banner.visible);
    Test.assert(clock.showDate);

    fixture.store.setHealthAlert(HEALTH_ALERT_HIGH_HEART_RATE);
    fixture.render();
    Test.assert(banner.visible);
    Test.assertEqual(banner.text, "Pulso alto en reposo");
    Test.assertEqual(banner.fill, WatchColors.WARNING);
    Test.assertEqual(banner.content, WatchColors.ON_WARNING);
    Test.assert(!clock.showDate);
    // The rest of the watchface keeps working.
    Test.assertEqual((fixture.view.heartRateIndicator() as HeartRateIndicator).bpm, 70);

    fixture.store.setHealthAlert(null);
    fixture.render();
    Test.assert(!banner.visible);
    Test.assert(clock.showDate);
    fixture.finish();
    return true;
}

(:test)
function banner_speaksEnglishWhenChosen(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture("en");
    fixture.store.setHealthAlert(HEALTH_ALERT_HIGH_HEART_RATE);
    fixture.render();
    Test.assertEqual((fixture.view.heartRateBanner() as HeartRateBanner).text, "High heart rate at rest");
    fixture.finish();
    return true;
}

(:test)
function banner_fitsTheRoundScreenBetweenTheTimeAndTheHeartRate(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var layout = new WatchfaceLayout(390, 390);
    var dc = fixture.dc;
    var banner = new HeartRateBanner(layout);
    var texts = ["Pulso alto en reposo", "High heart rate at rest"];
    for (var i = 0; i < texts.size(); i++) {
        banner.text = texts[i] as String;
        var width = banner.width(dc);
        logger.debug(banner.text + ": banner " + width + " px, at most " + layout.bannerMaxWidth);
        Test.assert(width <= layout.bannerMaxWidth);
        Test.assert(layout.fitsInCircle(layout.centerX - width / 2, layout.bannerY - layout.bannerHeight / 2,
            layout.centerX + width / 2, layout.bannerY + layout.bannerHeight / 2));
    }
    Test.assert(Graphics.getFontAscent(layout.bannerFont) <= layout.bannerHeight);
    // A VCENTER row centers the whole font height, so its digits end at the baseline (top plus
    // ascent) and the descent below them stays empty.
    var timeBaseline = layout.timeY - dc.getFontHeight(layout.timeFont) / 2 + Graphics.getFontAscent(layout.timeFont);
    // Digits rise about two thirds of the ascent above the baseline.
    var heartRateBaseline = layout.heartRateY - dc.getFontHeight(layout.heartRateFont) / 2
        + Graphics.getFontAscent(layout.heartRateFont);
    var heartRateTop = heartRateBaseline - Graphics.getFontAscent(layout.heartRateFont) * 2 / 3;
    logger.debug("banner " + (layout.bannerY - layout.bannerHeight / 2) + "-" + (layout.bannerY + layout.bannerHeight / 2)
        + ", time digits end at " + timeBaseline + ", heart rate digits start at " + heartRateTop);
    Test.assert(layout.bannerY - layout.bannerHeight / 2 > timeBaseline);
    Test.assert(layout.bannerY + layout.bannerHeight / 2 < heartRateTop);
    fixture.finish();
    return true;
}
