import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;
import Toybox.WatchUi;

// The fall countdown screen, like FallCountdownScreenTest.kt in wear-app. A fall is fed through
// the store with a fake clock; the countdown is advanced with tick() instead of its timer; the
// view is drawn into an off-screen 390x390 bitmap and input goes through the delegate's methods.

(:test)
class FallCountdownFixture {
    var store as TelemetryStore = new TelemetryStore();
    var clock as FakeClock = new FakeClock();
    var language as LanguagePreference;
    var sos as SosController;
    var fall as FallMonitor;
    var view as FallCountdownView;
    var delegate as FallCountdownDelegate;
    var layout as WatchfaceLayout = new WatchfaceLayout(390, 390);
    var dc as Graphics.Dc;

    function initialize(languageTag as String or Null) {
        language = new LanguagePreference(new MemoryLanguageStorage(languageTag));
        sos = new SosController(store);
        fall = new FallMonitor(store, FallDetector.standard(), clock);
        view = new FallCountdownView(fall, language);
        delegate = new FallCountdownDelegate(view, fall);
        var bitmap = Graphics.createBufferedBitmap({:width => 390, :height => 390}).get() as Graphics.BufferedBitmap;
        dc = bitmap.getDc();
        view.onLayout(dc);
    }

    // An impact, then stillness until the fall is confirmed, a reading per second.
    function simulateFall() as Void {
        var start = clock.time + 1000;
        TestReadings.write(store, clock, TestReadings.spike(), start);
        for (var t = start + 1000; t <= start + 1000 + FallDetectionConfig.IMMOBILITY_DURATION_MS; t += 1000) {
            TestReadings.write(store, clock, TestReadings.still(), t);
        }
    }

    function seconds(count as Number) as Void {
        for (var i = 0; i < count; i++) {
            fall.countdown().tick();
        }
    }

    function render() as Void {
        view.onUpdate(dc);
    }

    function mode() as DeviceMode {
        return store.getState().deviceStatus.mode;
    }

    function onButton() as [Number, Number] {
        return [layout.centerX, layout.fallButtonY] as [Number, Number];
    }

    // Leaves no countdown timer running after the test.
    function finish() as Void {
        fall.countdown().cancel();
    }
}

// --- Appearing ---

(:test)
function fallScreen_theCountdownStartsWhenAFallIsDetected(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    Test.assertEqual(f.mode(), MODE_MONITORING);
    f.simulateFall();
    Test.assertEqual(f.mode(), MODE_FALL_COUNTDOWN);
    Test.assert(f.fall.remainingSeconds() == FallDetectionConfig.COUNTDOWN_SECONDS);
    f.render();
    Test.assertEqual(f.view.question, "¿Te caíste?");
    Test.assertEqual(f.view.cancelLabel, "ESTOY BIEN");
    Test.assertEqual(f.view.seconds, FallDetectionConfig.COUNTDOWN_SECONDS);
    Test.assertEqual(f.view.ringDegrees, 360);
    Test.assert(!f.view.urgent);
    f.finish();
    return true;
}

(:test)
function fallScreen_stillnessWithoutAnImpactStartsNoCountdown(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    for (var t = 1000; t <= 20000; t += 1000) {
        TestReadings.write(f.store, f.clock, TestReadings.still(), t);
    }
    Test.assertEqual(f.mode(), MODE_MONITORING);
    Test.assert(f.fall.remainingSeconds() == null);
    return true;
}

(:test)
function fallScreen_opensAndClosesWithTheMode(logger as Logger) as Boolean {
    Test.assertEqual(AlertScreens.actionFor(MODE_MONITORING, MODE_MONITORING), SCREEN_NONE);
    Test.assertEqual(AlertScreens.actionFor(MODE_MONITORING, MODE_FALL_COUNTDOWN), SCREEN_PUSH);
    Test.assertEqual(AlertScreens.actionFor(MODE_FALL_COUNTDOWN, MODE_FALL_COUNTDOWN), SCREEN_NONE);
    Test.assertEqual(AlertScreens.actionFor(MODE_FALL_COUNTDOWN, MODE_MONITORING), SCREEN_POP);
    // A countdown reaching zero replaces its screen with the SOS one.
    Test.assertEqual(AlertScreens.actionFor(MODE_FALL_COUNTDOWN, MODE_SOS), SCREEN_SWITCH);
    Test.assertEqual(AlertScreens.actionFor(MODE_MONITORING, MODE_SOS), SCREEN_PUSH);
    Test.assertEqual(AlertScreens.actionFor(MODE_SOS, MODE_MONITORING), SCREEN_POP);
    return true;
}

// --- Counting down ---

(:test)
function fallScreen_theNumberCountsDownOncePerSecondAndTheRingDrains(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    f.seconds(1);
    f.render();
    Test.assertEqual(f.view.seconds, 9);
    Test.assertEqual(f.view.ringDegrees, 324);
    f.seconds(4);
    f.render();
    Test.assertEqual(f.view.seconds, 5);
    Test.assertEqual(f.view.ringDegrees, 180);
    Test.assert(!f.view.urgent);
    f.finish();
    return true;
}

(:test)
function fallScreen_turnsRedInTheLastSeconds(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    f.seconds(FallDetectionConfig.COUNTDOWN_SECONDS - FallDetectionConfig.URGENT_SECONDS - 1);
    f.render();
    Test.assert(!f.view.urgent);
    f.seconds(1);
    f.render();
    Test.assertEqual(f.view.seconds, FallDetectionConfig.URGENT_SECONDS);
    Test.assert(f.view.urgent);
    f.finish();
    return true;
}

(:test)
function fallScreen_drawsEverySecondInBothLanguagesWithoutErrors(logger as Logger) as Boolean {
    var tags = [null, "en"];
    for (var i = 0; i < tags.size(); i++) {
        var f = new FallCountdownFixture(tags[i] as String or Null);
        f.simulateFall();
        for (var s = FallDetectionConfig.COUNTDOWN_SECONDS; s > 0; s--) {
            f.render();
            Test.assertEqual(f.view.seconds, s);
            f.seconds(1);
        }
        f.render();
        Test.assertEqual(f.view.seconds, 0);
        Test.assertEqual(f.view.ringDegrees, 0);
        f.finish();
    }
    return true;
}

(:test)
function fallScreen_speaksEnglishWhenChosen(logger as Logger) as Boolean {
    var f = new FallCountdownFixture("en");
    f.simulateFall();
    f.render();
    Test.assertEqual(f.view.question, "Did you fall?");
    Test.assertEqual(f.view.cancelLabel, "I'M OK");
    f.finish();
    return true;
}

// --- Layout ---

(:test)
function fallScreen_everyElementFitsInsideTheRing(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    var layout = f.layout;
    var dc = f.dc;
    var radius = layout.fallContentRadius;
    // The ring stays on screen and the BACK hint at the edge stays clear of it.
    Test.assert(layout.fallRingRadius + layout.fallRingWidth / 2 < layout.width / 2 - layout.scale(10));
    // The question, in the font the view picks, in both languages.
    var questions = ["¿Te caíste?", "Did you fall?"];
    for (var i = 0; i < questions.size(); i++) {
        var text = questions[i] as String;
        var font = layout.fittingFont(dc, text, layout.titleFonts, layout.fallTitleY, radius);
        var width = dc.getTextWidthInPixels(text, font);
        var half = Graphics.getFontAscent(font) / 2;
        logger.debug(text + ": " + width + " px, font " + font);
        Test.assert(width <= layout.widthInCircle(layout.fallTitleY, half, radius));
        Test.assert(layout.fitsInCircle(layout.centerX - width / 2, layout.fallTitleY - half, layout.centerX + width / 2,
            layout.fallTitleY + half));
    }
    // The seconds, between the question and the button.
    var secondsHalf = Graphics.getFontAscent(layout.fallSecondsFont) / 2;
    var titleBottom = layout.fallTitleY + Graphics.getFontAscent(Graphics.FONT_LARGE) / 2;
    Test.assert(layout.fallSecondsY - secondsHalf >= titleBottom - layout.scale(10));
    Test.assert(layout.fallSecondsY + secondsHalf <= layout.fallButtonY - layout.fallButtonHeight / 2);
    // The button: its rounded ends stay inside the ring.
    var capRadius = layout.fallButtonHeight / 2;
    var capX = layout.fallButtonWidth / 2 - capRadius;
    var capY = layout.fallButtonY - layout.height / 2;
    var reach = Math.sqrt(capX * capX + capY * capY) + capRadius;
    logger.debug("button reaches " + reach + " px from the center, limit " + radius);
    Test.assert(reach <= radius);
    // Both labels fit the button in a font at least as large as FONT_SMALL.
    var labels = ["ESTOY BIEN", "I'M OK"];
    for (var i = 0; i < labels.size(); i++) {
        var label = labels[i] as String;
        var font = layout.fontForWidth(dc, label, layout.titleFonts, layout.fallButtonWidth - capRadius);
        Test.assert(dc.getTextWidthInPixels(label, font) <= layout.fallButtonWidth - capRadius);
    }
    f.finish();
    return true;
}

// --- "Estoy bien" ---

(:test)
function fallScreen_backCancelsTheCountdownAndRestoresMonitoring(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    f.seconds(3);
    Test.assert(f.delegate.onBack());
    Test.assertEqual(f.mode(), MODE_MONITORING);
    Test.assert(f.fall.remainingSeconds() == null);
    Test.assert(!f.fall.countdown().isRunning());
    return true;
}

(:test)
function fallScreen_aTapOrAHeldFingerOnTheButtonCancels(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    Test.assert(f.delegate.touched(f.onButton()));
    Test.assertEqual(f.mode(), MODE_MONITORING);

    // onHold, for a finger kept on the button, goes through the same method.
    f.simulateFall();
    Test.assertEqual(f.mode(), MODE_FALL_COUNTDOWN);
    var edge = [f.layout.centerX + f.layout.fallButtonWidth / 2 + 5, f.layout.fallButtonY] as [Number, Number];
    Test.assert(f.delegate.touched(edge));
    Test.assertEqual(f.mode(), MODE_MONITORING);
    return true;
}

(:test)
function fallScreen_otherInputNeverCancels(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    // Touches away from the button, on the number and the question.
    f.delegate.touched([f.layout.centerX, f.layout.fallSecondsY] as [Number, Number]);
    f.delegate.touched([f.layout.centerX, f.layout.fallTitleY] as [Number, Number]);
    // START, the SOS button, and the other keys are swallowed; only BACK goes through.
    var keys = [WatchUi.KEY_ENTER, WatchUi.KEY_UP, WatchUi.KEY_DOWN];
    for (var i = 0; i < keys.size(); i++) {
        Test.assert(f.delegate.swallows(keys[i] as WatchUi.Key));
    }
    Test.assert(!f.delegate.swallows(WatchUi.KEY_ESC));
    Test.assert(f.delegate.onMenu());
    Test.assert(f.delegate.onNextPage());
    Test.assert(f.delegate.onPreviousPage());
    Test.assertEqual(f.mode(), MODE_FALL_COUNTDOWN);
    Test.assert(f.fall.countdown().isRunning());
    f.finish();
    return true;
}

(:test)
function fallScreen_cancelOnlyActsDuringACountdown(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.sos.activate();
    f.fall.cancel();
    Test.assertEqual(f.mode(), MODE_SOS);
    return true;
}

(:test)
function fallScreen_monitoringResumesAfterCancellingSoANewFallIsDetected(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    f.delegate.onBack();
    Test.assertEqual(f.fall.getDetectorState(), FALL_IDLE);
    f.simulateFall();
    Test.assertEqual(f.mode(), MODE_FALL_COUNTDOWN);
    Test.assert(f.fall.remainingSeconds() == FallDetectionConfig.COUNTDOWN_SECONDS);
    f.finish();
    return true;
}

(:test)
function fallScreen_leavingTheCountdownModeAnyOtherWayStopsTheCountdown(logger as Logger) as Boolean {
    var f = new FallCountdownFixture(null);
    f.simulateFall();
    f.store.setMode(MODE_MONITORING);
    Test.assert(!f.fall.countdown().isRunning());
    return true;
}

// --- Vibration ---

(:test)
function fallScreen_vibratesMoreUrgentlyAsTimeRunsOut(logger as Logger) as Boolean {
    var normal = Vibration.countdownPattern(FallDetectionConfig.URGENT_SECONDS + 1);
    var urgent = Vibration.countdownPattern(FallDetectionConfig.URGENT_SECONDS);
    var alert = Vibration.countdownPattern(0);
    // Pulses at full strength separated by silences, since intensity is ignored.
    Test.assertEqual(VibePatterns.pulseCount(normal), Vibration.COUNTDOWN_PULSES);
    Test.assertEqual(VibePatterns.pulseCount(urgent), Vibration.URGENT_PULSES);
    Test.assertEqual(VibePatterns.pulseCount(alert), 1);
    Test.assertEqual(VibePatterns.totalMs(alert), Vibration.ALERT_MS);
    // Every per-second pattern ends well before the next second.
    for (var s = FallDetectionConfig.COUNTDOWN_SECONDS; s > 0; s--) {
        Test.assert(VibePatterns.totalMs(Vibration.countdownPattern(s)) < Countdown.TICK_MS);
    }
    return true;
}

// Measures vibration patterns. Static functions, since a global (:test) function is a test.
(:test)
class VibePatterns {
    static function pulseCount(pattern as Array<Attention.VibeProfile>) as Number {
        var count = 0;
        for (var i = 0; i < pattern.size(); i++) {
            if (pattern[i].dutyCycle > 0) {
                count++;
            }
        }
        return count;
    }

    static function totalMs(pattern as Array<Attention.VibeProfile>) as Number {
        var total = 0;
        for (var i = 0; i < pattern.size(); i++) {
            total += pattern[i].length;
        }
        return total;
    }
}
