import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The text of the alert on screen: "Generando mensaje…" while it is generated, the message page
// of the SOS screen and the critical heart rate banner. The message source is a fake that answers
// when the test says (SosScreenFixture and DeviceHarness in the other test files).

(:test)
class SosMessageScreens {
    // An SOS screen whose message source waits until answer() is called.
    static function waiting(languageTag as String or Null) as SosScreenFixture {
        var f = new SosScreenFixture(languageTag);
        f.device.messages.answerAtOnce = false;
        f.device.sos.activate(SOS_REASON_MANUAL);
        return f;
    }
}

(:test)
function sosMessage_saysItIsGeneratingUntilTheMessageIsReady(logger as Logger) as Boolean {
    var f = SosMessageScreens.waiting(null);
    f.render();
    Test.assert(f.view.confirming);
    Test.assertEqual(f.view.notified, "Generando mensaje…");
    // The contacts and the location are already there.
    Test.assertEqual(f.view.contactNames.size(), 3);
    Test.assertEqual(f.view.coordinates, "4.60970, -74.08170");
    f.device.messages.answer(0, "Tu familiar pidió ayuda.");
    f.render();
    Test.assertEqual(f.view.notified, "Avisados (simulado)");
    return true;
}

(:test)
function sosMessage_theFallbackLooksTheSameAsAnAnswer(logger as Logger) as Boolean {
    var f = SosMessageScreens.waiting("en");
    f.render();
    Test.assertEqual(f.view.notified, "Generating message…");
    f.device.messages.answer(0, null);
    f.render();
    Test.assertEqual(f.view.notified, "Notified (mock)");
    Test.assertEqual(f.view.contactNames.size(), 3);
    return true;
}

(:test)
function sosMessage_downShowsGeminisTextAndUpGoesBack(logger as Logger) as Boolean {
    var f = SosMessageScreens.waiting(null);
    f.device.messages.answer(0, "Tu familiar pidió ayuda con el botón SOS. Ubicación GPS adjunta.");
    Test.assert(f.delegate.onNextPage());
    f.render();
    Test.assert(f.view.showingMessage);
    Test.assertEqual(f.view.messageLabel, "Mensaje de IA");
    Test.assertEqual(f.view.messageText, "Tu familiar pidió ayuda con el botón SOS. Ubicación GPS adjunta.");
    Test.assert(f.delegate.onPreviousPage());
    f.render();
    Test.assert(!f.view.showingMessage);
    Test.assertEqual(f.view.notified, "Avisados (simulado)");
    return true;
}

(:test)
function sosMessage_theMessagePageSaysWhenItIsTheTemplate(logger as Logger) as Boolean {
    var tags = [null, "en"];
    var labels = ["Mensaje predefinido", "Standard message"];
    for (var i = 0; i < tags.size(); i++) {
        var f = SosMessageScreens.waiting(tags[i] as String or Null);
        f.device.messages.answer(0, null);
        f.delegate.onNextPage();
        f.render();
        Test.assertEqual(f.view.messageLabel, labels[i] as String);
        Test.assertEqual(f.view.messageText, (f.device.alerts.sosAlert() as AlertPayload).message as String);
    }
    return true;
}

(:test)
function sosMessage_theMessagePageWhileGenerating(logger as Logger) as Boolean {
    var f = SosMessageScreens.waiting(null);
    f.delegate.onNextPage();
    f.render();
    Test.assertEqual(f.view.messageLabel, "");
    Test.assertEqual(f.view.messageText, "Generando mensaje…");
    f.device.messages.answer(0, "Listo.");
    f.render();
    Test.assertEqual(f.view.messageText, "Listo.");
    return true;
}

(:test)
function sosMessage_cancelWorksOnTheMessagePage(logger as Logger) as Boolean {
    var f = SosMessageScreens.waiting(null);
    f.device.messages.answer(0, null);
    f.delegate.onNextPage();
    f.render();
    f.delegate.tapped([f.layout.centerX, f.layout.confirmCancelY] as [Number, Number]);
    Test.assertEqual(f.device.mode(), MODE_MONITORING);
    return true;
}

(:test)
function sosMessage_upAndDownReachThePagesWhileOtherKeysStaySwallowed(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    Test.assert(!f.delegate.swallows(WatchUi.KEY_DOWN));
    Test.assert(!f.delegate.swallows(WatchUi.KEY_UP));
    Test.assert(!f.delegate.swallows(WatchUi.KEY_ESC));
    Test.assert(f.delegate.swallows(WatchUi.KEY_ENTER));
    return true;
}

(:test)
function sosMessage_theMessagePageFitsTheRoundScreen(logger as Logger) as Boolean {
    var f = new SosScreenFixture(null);
    var layout = f.layout;
    var radius = layout.sosSafeRadius;
    // The labels in both languages, at their row.
    var labels = ["Mensaje predefinido", "Standard message", "Mensaje de IA", "AI message"];
    var font = layout.detailFont;
    var half = Graphics.getFontAscent(font) / 2;
    for (var i = 0; i < labels.size(); i++) {
        var width = f.dc.getTextWidthInPixels(labels[i] as String, font);
        Test.assertMessage(width <= layout.widthInCircle(layout.messageLabelY, half, radius), (labels[i] as String) + " leaves the screen");
    }
    // The text box: below the label, above the cancel button, its corners inside the circle.
    var left = layout.centerX - layout.messageWidth / 2;
    var top = layout.messageY - layout.messageHeight / 2;
    var bottom = layout.messageY + layout.messageHeight / 2;
    Test.assert(top >= layout.messageLabelY + half - layout.scale(2));
    Test.assert(bottom <= layout.confirmCancelY - layout.confirmCancelHeight / 2);
    var shrunk = new WatchfaceLayout(2 * radius, 2 * radius);
    var offset = layout.width / 2 - radius;
    Test.assert(shrunk.fitsInCircle(left - offset, top - offset, left + layout.messageWidth - offset, bottom - offset));
    // Both chevrons inside the screen.
    Test.assert(layout.inCircle(layout.centerX + layout.chevronSize, layout.pageDownY + layout.chevronSize / 2));
    Test.assert(layout.inCircle(layout.centerX + layout.chevronSize, layout.pageUpY - layout.chevronSize / 2));
    return true;
}

(:test)
function sosMessage_bothPagesDrawWithLongTextsInBothLanguages(logger as Logger) as Boolean {
    var tags = [null, "en"];
    var long = "Tu familiar sufrió una caída y no respondió a la cuenta regresiva. Pulso 70 LPM, ubicación GPS adjunta; por favor llama de inmediato o acude al lugar.";
    for (var i = 0; i < tags.size(); i++) {
        var f = SosMessageScreens.waiting(tags[i] as String or Null);
        f.render();
        f.delegate.onNextPage();
        f.render();
        f.device.messages.answer(0, long);
        f.render();
        Test.assertEqual(f.view.messageText, long);
        f.delegate.onPreviousPage();
        f.render();
    }
    return true;
}

// --- The critical heart rate banner ---

(:test)
function sosMessage_theCriticalBannerSaysItIsGeneratingUntilTheMessageIsReady(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var clock = new FakeClock();
    var messages = new FakeMessageSource();
    messages.answerAtOnce = false;
    new HeartRateMonitor(fixture.store, HeartRateAnomalyDetector.warning(), clock);
    var critical = new AlertDispatcher(fixture.store, fixture.sos, HeartRateAnomalyDetector.critical(), clock,
        fixture.language, messages);
    var view = new WatchfaceView(fixture.store, fixture.language, fixture.controller, critical);
    view.onLayout(fixture.dc);
    for (var i = 0; i < Times.toConfirm(); i++) {
        clock.time += 1000;
        var next = fixture.store.getState();
        next.heartRate = new HeartRate(DeviceHarness.CRITICAL);
        next.deviceStatus = new DeviceStatus(MODE_MONITORING, clock.time.toLong(), next.deviceStatus.healthAlert);
        fixture.store.update(next);
    }
    view.onUpdate(fixture.dc);
    var banner = view.heartRateBanner() as HeartRateBanner;
    Test.assert(banner.visible);
    Test.assert(banner.critical);
    Test.assertEqual(banner.text, "Generando mensaje…");
    messages.answer(0, null);
    view.onUpdate(fixture.dc);
    Test.assertEqual(banner.text, "Pulso crítico: familia avisada");
    fixture.finish();
    return true;
}

(:test)
function sosMessage_theGeneratingBannerFitsInBothLanguages(logger as Logger) as Boolean {
    var fixture = new WatchfaceFixture(null);
    var layout = new WatchfaceLayout(390, 390);
    var banner = new HeartRateBanner(layout);
    banner.setCritical(true);
    var texts = ["Generando mensaje…", "Generating message…"];
    for (var i = 0; i < texts.size(); i++) {
        banner.text = texts[i] as String;
        Test.assert(banner.width(fixture.dc) <= layout.bannerMaxWidth);
    }
    return true;
}
