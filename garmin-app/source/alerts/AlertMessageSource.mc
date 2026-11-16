import Toybox.Lang;

// Where AlertDispatcher gets the text of an alert. This base class has no AI: it answers null at
// once, so every alert uses the static template (AlertMessages.template). Tests replace it with a
// fake that answers when they say.
class AlertMessageSource {
    function initialize() {
    }

    // Answers callback exactly once, with the text or with null (use the template).
    function request(context as AlertMessageContext, callback as AlertMessageCallback) as Void {
        callback.invoke(null);
    }

    // Stops waiting for every request in progress; their callbacks are never answered.
    function cancelAll() as Void {
    }
}

// The text comes from Gemini (GeminiService.requestAlertMessage), with its timeout. Keeps the
// requests in progress so a reset can cancel them.
class GeminiMessageSource extends AlertMessageSource {
    private var _requests as Array<GeminiRequest> = [] as Array<GeminiRequest>;

    function initialize() {
        AlertMessageSource.initialize();
    }

    function request(context as AlertMessageContext, callback as AlertMessageCallback) as Void {
        var running = [] as Array<GeminiRequest>;
        for (var i = 0; i < _requests.size(); i++) {
            if (!_requests[i].isDone()) {
                running.add(_requests[i]);
            }
        }
        _requests = running;
        _requests.add(GeminiService.requestAlertMessage(context, callback));
    }

    function cancelAll() as Void {
        for (var i = 0; i < _requests.size(); i++) {
            _requests[i].cancel();
        }
        _requests = [] as Array<GeminiRequest>;
    }
}

// The static text of an alert, used whenever Gemini does not answer in time: the event, the
// heart rate and the location, in the app language. The wording is in the string resources.
module AlertMessages {
    function template(alert as AlertPayload, language as LanguagePreference) as String {
        var format;
        if (alert.type == ALERT_FALL) {
            format = language.text(Rez.Strings.AlertTemplateFall, Rez.Strings.AlertTemplateFallEn);
        } else if (alert.type == ALERT_MANUAL_SOS) {
            format = language.text(Rez.Strings.AlertTemplateManualSos, Rez.Strings.AlertTemplateManualSosEn);
        } else {
            format = language.text(Rez.Strings.AlertTemplateHighHeartRate, Rez.Strings.AlertTemplateHighHeartRateEn);
        }
        return Lang.format(format, [alert.heartRate, GeminiService.locationDescription(alert.gps, language.getLanguage())]);
    }
}
