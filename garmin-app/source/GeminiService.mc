import Toybox.Communications;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Receives the text Gemini wrote for an alert, or null when there is none: no answer within the
// timeout, no connection, an HTTP error or an answer of an unexpected shape. Null means "use the
// static template".
typedef AlertMessageCallback as Method(text as String or Null) as Void;

// What the prompt of an alert is made of: what happened, the readings it carries and the language
// to write in.
class AlertMessageContext {
    var eventType as AlertType;
    var heartRate as Number;
    var timestamp as Long;
    var location as Gps;
    var language as AppLanguage;

    function initialize(eventType as AlertType, heartRate as Number, timestamp as Long, location as Gps, language as AppLanguage) {
        self.eventType = eventType;
        self.heartRate = heartRate;
        self.timestamp = timestamp;
        self.location = location;
        self.language = language;
    }

    static function of(alert as AlertPayload, language as AppLanguage) as AlertMessageContext {
        return new AlertMessageContext(alert.type, alert.heartRate, alert.timestamp, alert.gps, language);
    }
}

// One request to Gemini, which answers its callback exactly once: with the text, or with null
// when the answer is not usable or does not come within GeminiConfig.TIMEOUT_MS. An answer that
// arrives after the timeout is ignored. The timer is one-shot and is released when the request
// ends, since apps may only have a few timers.
//
// On the watch, makeWebRequest goes through the paired phone (Garmin Connect); without a phone or
// internet it fails at once (a negative code), which also means the template.
class GeminiRequest {
    private var _callback as AlertMessageCallback;
    private var _timer as Timer.Timer or Null = null;
    private var _done as Boolean = false;

    function initialize(callback as AlertMessageCallback) {
        _callback = callback;
    }

    // True once the callback was answered or the request was cancelled.
    function isDone() as Boolean {
        return _done;
    }

    function start(body as Dictionary<Object, Object>) as Void {
        try {
            var timer = new Timer.Timer();
            timer.start(method(:onTimeout), GeminiConfig.TIMEOUT_MS, false);
            _timer = timer;
            Communications.makeWebRequest(GeminiService.url(), body, {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                // The key goes in a header, not in the URL, so it does not end up in request logs.
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                    "x-goog-api-key" => GEMINI_API_KEY,
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            }, method(:onResponse));
        } catch (e) {
            finish(null, "request failed");
        }
    }

    // The answer of makeWebRequest: 200 with the parsed JSON, or an HTTP error, or a negative
    // Connect IQ code (no phone, no internet, answer too large...).
    function onResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        var text = responseCode == 200 ? GeminiService.parseResponse(data) : null;
        finish(text, "HTTP " + responseCode);
    }

    function onTimeout() as Void {
        finish(null, "timeout");
    }

    // Stops waiting without answering the callback.
    function cancel() as Void {
        _done = true;
        stopTimer();
    }

    private function finish(text as String or Null, outcome as String) as Void {
        if (_done) {
            return;
        }
        _done = true;
        stopTimer();
        System.println("Gemini " + outcome + (text != null ? ": message received" : ": using the static template"));
        _callback.invoke(text);
    }

    private function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }
}

// Asks Gemini (Google AI) to write the text of an alert for an emergency contact. The functions
// here are pure: they build the prompt and the request body and read the answer, so they are
// tested without a network.
//
// The prompt is written in the app language, with its wording in the string resources
// (GeminiPrompt and GeminiPromptEn), so no language is hardcoded. It is sent to Gemini and never
// shown on screen.
module GeminiService {
    // Asks Gemini for the text of the alert described by context. The callback receives the text,
    // or null (use the static template) on a timeout or any error. The request is returned so
    // the caller can cancel it.
    function requestAlertMessage(context as AlertMessageContext, callback as AlertMessageCallback) as GeminiRequest {
        var request = new GeminiRequest(callback);
        var prompt = buildAlertPrompt(context.eventType, context.heartRate, context.timestamp, context.location, context.language);
        request.start(buildRequestBody(prompt));
        return request;
    }

    // The generateContent endpoint of the configured model.
    function url() as String {
        return GeminiConfig.ENDPOINT + GeminiConfig.MODEL + ":generateContent";
    }

    // The prompt for an alert of eventType, with the readings it carries: the heart rate in BPM,
    // its time (epoch milliseconds) and where it says the person is.
    function buildAlertPrompt(
        eventType as AlertType,
        heartRate as Number,
        timestamp as Long,
        location as Gps,
        language as AppLanguage
    ) as String {
        return Lang.format(text(language, Rez.Strings.GeminiPrompt, Rez.Strings.GeminiPromptEn), [
            eventDescription(eventType, language),
            heartRate,
            clockTime(timestamp),
            locationDescription(location, language),
        ]);
    }

    // The body generateContent expects: one user turn with one text part, and a cap on the answer.
    function buildRequestBody(prompt as String) as Dictionary<Object, Object> {
        return {
            "contents" => [{"parts" => [{"text" => prompt}]}],
            "generationConfig" => {"maxOutputTokens" => GeminiConfig.MAX_OUTPUT_TOKENS},
        } as Dictionary<Object, Object>;
    }

    // The text of candidates[0].content.parts[0].text, cleaned up for the screen, or null when
    // the answer does not have that shape or the text is empty. Never throws: any unexpected
    // answer means "use the static template".
    //
    // Gemini 3 models may split the answer over several parts, or add parts with the model's
    // thoughts (marked "thought": true). So the text is that of every part in order, thoughts
    // left out; with one part, as usual, it is exactly parts[0].text.
    function parseResponse(response as Dictionary or String or Null) as String or Null {
        var candidates = field(response, "candidates");
        if (!(candidates instanceof Array) || candidates.size() == 0) {
            return null;
        }
        var parts = field(field(candidates[0] as Object or Null, "content"), "parts");
        if (!(parts instanceof Array)) {
            return null;
        }
        var text = "";
        for (var i = 0; i < parts.size(); i++) {
            var part = parts[i] as Object or Null;
            var partText = field(part, "text");
            var thought = field(part, "thought");
            if (partText instanceof String && !(thought instanceof Boolean && thought)) {
                text += partText;
            }
        }
        return clean(text);
    }

    // The value at key when container is a Dictionary; null otherwise.
    function field(container as Object or Null, key as String) as Object or Null {
        return container instanceof Dictionary ? container.get(key) as Object or Null : null;
    }

    // The text on one line, without the spaces or quotes around it; null if nothing is left.
    function clean(text as String) as String or Null {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == '\n' || chars[i] == '\r' || chars[i] == '\t') {
                chars[i] = ' ';
            }
        }
        var start = 0;
        var end = chars.size();
        while (start < end && isTrimmed(chars[start])) {
            start++;
        }
        while (end > start && isTrimmed(chars[end - 1])) {
            end--;
        }
        if (start == end) {
            return null;
        }
        return StringUtil.charArrayToString(chars.slice(start, end));
    }

    // 24-hour local time, "15:07", which the model rewrites as it sees fit.
    function clockTime(timestamp as Long) as String {
        var info = Gregorian.info(new Time.Moment((timestamp / 1000).toNumber()), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    function eventDescription(eventType as AlertType, language as AppLanguage) as String {
        if (eventType == ALERT_FALL) {
            return text(language, Rez.Strings.GeminiEventFall, Rez.Strings.GeminiEventFallEn);
        }
        return eventType == ALERT_MANUAL_SOS
            ? text(language, Rez.Strings.GeminiEventManualSos, Rez.Strings.GeminiEventManualSosEn)
            : text(language, Rez.Strings.GeminiEventHighHeartRate, Rez.Strings.GeminiEventHighHeartRateEn);
    }

    // The coordinates, saying whether they are the current GPS position or the last one known.
    function locationDescription(location as Gps, language as AppLanguage) as String {
        var format = location.signal
            ? text(language, Rez.Strings.GeminiLocationGps, Rez.Strings.GeminiLocationGpsEn)
            : text(language, Rez.Strings.GeminiLocationLast, Rez.Strings.GeminiLocationLastEn);
        return Lang.format(format, [SosView.formatCoordinate(location.lat), SosView.formatCoordinate(location.lng)]);
    }

    function text(language as AppLanguage, spanish as ResourceId, english as ResourceId) as String {
        return WatchUi.loadResource(language == LANGUAGE_EN ? english : spanish) as String;
    }

    function isTrimmed(c as Char) as Boolean {
        return c == ' ' || c == '"';
    }
}
