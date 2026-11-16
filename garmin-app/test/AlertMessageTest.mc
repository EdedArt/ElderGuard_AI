import Toybox.Lang;
import Toybox.Test;

// The text of each alert: Gemini's when it answers, the static template when it answers null,
// on a whole device (DeviceHarness) with a FakeMessageSource instead of the network. Also the
// handlers of GeminiRequest, called by hand: the answer, the timeout and a late answer.

(:test)
class MessageRecorder {
    var calls as Number = 0;
    var text as String or Null = null;

    function initialize() {
    }

    function onText(text as String or Null) as Void {
        calls += 1;
        self.text = text;
    }

    function callback() as AlertMessageCallback {
        return method(:onText) as AlertMessageCallback;
    }
}

(:test)
class MessageDevices {
    // A device whose message source keeps every request until the test answers it.
    static function waiting() as DeviceHarness {
        var d = new DeviceHarness();
        d.messages.answerAtOnce = false;
        return d;
    }

    static function fallSos(d as DeviceHarness) as AlertPayload {
        d.simulateFall();
        d.seconds(FallDetectionConfig.COUNTDOWN_SECONDS);
        return d.alerts.alerts()[0];
    }

    static function critical(d as DeviceHarness) as AlertPayload {
        d.holdRate(DeviceHarness.CRITICAL, TestReadings.still());
        d.seconds(Times.toConfirm());
        return d.alerts.alerts()[0];
    }

    static function contains(text as String or Null, part as String) as Boolean {
        return text != null && text.find(part) != null;
    }
}

(:test)
function alertMessage_aFallSosAsksForTheTextOfThatFallInTheAppLanguage(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    d.language.setLanguage(LANGUAGE_EN);
    var alert = MessageDevices.fallSos(d);
    Test.assertEqual(d.messages.contexts.size(), 1);
    var context = d.messages.contexts[0];
    Test.assertEqual(context.eventType, ALERT_FALL);
    Test.assertEqual(context.heartRate, alert.heartRate);
    Test.assertEqual(context.timestamp, alert.timestamp);
    Test.assert(context.location.equals(alert.gps));
    Test.assertEqual(context.language, LANGUAGE_EN);
    d.finish();
    return true;
}

(:test)
function alertMessage_theMessageIsPendingUntilTheSourceAnswers(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var alert = MessageDevices.fallSos(d);
    // The alert is recorded, and the SOS screen shows it, while its text is generated.
    Test.assert(d.alerts.sosAlert() == alert);
    Test.assert(alert.isMessagePending());
    Test.assert(alert.message == null);
    d.finish();
    return true;
}

(:test)
function alertMessage_geminisTextBecomesTheMessage(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var alert = MessageDevices.fallSos(d);
    d.messages.answer(0, "Ana, tu padre se cayó y no responde. Está en 4.60970, -74.08170.");
    Test.assertEqual(alert.messageOrigin, MESSAGE_AI);
    Test.assertEqual(alert.message as String, "Ana, tu padre se cayó y no responde. Está en 4.60970, -74.08170.");
    d.finish();
    return true;
}

(:test)
function alertMessage_noAnswerFromGeminiGivesTheStaticTemplate(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var alert = MessageDevices.fallSos(d);
    d.messages.answer(0, null);
    Test.assertEqual(alert.messageOrigin, MESSAGE_TEMPLATE);
    Test.assertEqual(alert.message as String,
        "ElderGuard AI: se detectó una caída y la persona no respondió. Pulso: 70 LPM. Ubicación: 4.60970, -74.08170 (GPS).");
    // Nothing else changes: the same alert, still confirmed on the SOS screen.
    Test.assertEqual(d.count(), 1);
    Test.assert(d.alerts.sosAlert() == alert);
    Test.assertEqual(d.mode(), MODE_SOS);
    d.finish();
    return true;
}

(:test)
function alertMessage_theTemplateCoversEveryAlertInBothLanguages(logger as Logger) as Boolean {
    var d = new DeviceHarness();
    d.language.setLanguage(LANGUAGE_EN);
    d.gps = new Gps(4.6097d, -74.0817d, 3.0d, false);
    d.seconds(2);
    d.sos.activate(SOS_REASON_MANUAL);
    var manual = d.alerts.alerts()[0];
    Test.assertEqual(manual.message as String,
        "ElderGuard AI: the person asked for help with the SOS button. Heart rate: 70 BPM. Location: last known position 4.60970, -74.08170 (no GPS signal).");

    var es = new DeviceHarness();
    var critical = MessageDevices.critical(es);
    Test.assertEqual(critical.message as String,
        "ElderGuard AI: pulso crítico de " + DeviceHarness.CRITICAL + " LPM en reposo. Ubicación: 4.60970, -74.08170 (GPS).");
    return true;
}

(:test)
function alertMessage_aCriticalHeartRateAlertGetsItsTextTheSameWay(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var alert = MessageDevices.critical(d);
    Test.assertEqual(d.messages.contexts[0].eventType, ALERT_HIGH_HEART_RATE);
    Test.assert(d.alerts.criticalAlert() == alert);
    Test.assert(alert.isMessagePending());
    d.messages.answer(0, "Pulso crítico de tu madre en reposo.");
    Test.assertEqual(alert.messageOrigin, MESSAGE_AI);
    return true;
}

(:test)
function alertMessage_aManualSosGetsItsTextTheSameWay(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    d.sos.activate(SOS_REASON_MANUAL);
    Test.assertEqual(d.messages.contexts[0].eventType, ALERT_MANUAL_SOS);
    d.messages.answer(0, null);
    Test.assertEqual((d.alerts.sosAlert() as AlertPayload).messageOrigin, MESSAGE_TEMPLATE);
    return true;
}

(:test)
function alertMessage_onlyTheFirstAnswerCounts(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var alert = MessageDevices.fallSos(d);
    d.messages.answer(0, null);
    d.messages.answer(0, "Too late");
    Test.assertEqual(alert.messageOrigin, MESSAGE_TEMPLATE);
    Test.assert(!MessageDevices.contains(alert.message, "Too late"));
    d.finish();
    return true;
}

(:test)
function alertMessage_eachAlertKeepsItsOwnText(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    var critical = MessageDevices.critical(d);
    d.sos.activate(SOS_REASON_MANUAL);
    var manual = d.alerts.sosAlert() as AlertPayload;
    // Answered in the opposite order.
    d.messages.answer(1, "SOS text");
    d.messages.answer(0, null);
    Test.assertEqual(manual.message as String, "SOS text");
    Test.assertEqual(critical.messageOrigin, MESSAGE_TEMPLATE);
    return true;
}

(:test)
function alertMessage_resetStopsWaitingForMessages(logger as Logger) as Boolean {
    var d = MessageDevices.waiting();
    MessageDevices.critical(d);
    d.alerts.reset();
    Test.assertEqual(d.messages.cancelCount, 1);
    Test.assert(d.alerts.criticalAlert() == null);
    Test.assertEqual(d.count(), 0);
    return true;
}

// --- GeminiRequest, without starting it (no network) ---

(:test)
function geminiRequest_aValidAnswerGivesItsText(logger as Logger) as Boolean {
    var recorder = new MessageRecorder();
    var request = new GeminiRequest(recorder.callback());
    request.onResponse(200, GeminiSamples.answer("Caída detectada."));
    Test.assertEqual(recorder.calls, 1);
    Test.assertEqual(recorder.text as String, "Caída detectada.");
    Test.assert(request.isDone());
    return true;
}

(:test)
function geminiRequest_errorsGiveNull(logger as Logger) as Boolean {
    // An HTTP error, no phone connection (Communications.BLE_CONNECTION_UNAVAILABLE) and an
    // unexpected answer.
    var codes = [503, -104, 200] as Array<Number>;
    for (var i = 0; i < codes.size(); i++) {
        var recorder = new MessageRecorder();
        new GeminiRequest(recorder.callback()).onResponse(codes[i], {"error" => "unavailable"});
        Test.assertEqual(recorder.calls, 1);
        Test.assert(recorder.text == null);
    }
    return true;
}

(:test)
function geminiRequest_aTimeoutGivesNullAndALateAnswerIsIgnored(logger as Logger) as Boolean {
    var recorder = new MessageRecorder();
    var request = new GeminiRequest(recorder.callback());
    request.onTimeout();
    request.onResponse(200, GeminiSamples.answer("Too late"));
    Test.assertEqual(recorder.calls, 1);
    Test.assert(recorder.text == null);
    return true;
}

(:test)
function geminiRequest_aCancelledRequestNeverAnswers(logger as Logger) as Boolean {
    var recorder = new MessageRecorder();
    var request = new GeminiRequest(recorder.callback());
    request.cancel();
    request.onResponse(200, GeminiSamples.answer("Caída detectada."));
    request.onTimeout();
    Test.assertEqual(recorder.calls, 0);
    return true;
}
