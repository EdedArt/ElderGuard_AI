import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Asks Gemini (Google AI) to write the text of an alert for an emergency contact. The functions
// here are pure: they build the prompt and the request body and read the answer, so they are
// tested without a network.
//
// The prompt is written in the app language, with its wording in the string resources
// (GeminiPrompt and GeminiPromptEn), so no language is hardcoded. It is sent to Gemini and never
// shown on screen.
module GeminiService {
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
    function buildRequestBody(prompt as String) as Dictionary<String, Object> {
        return {
            "contents" => [{"parts" => [{"text" => prompt}]}],
            "generationConfig" => {"maxOutputTokens" => GeminiConfig.MAX_OUTPUT_TOKENS},
        } as Dictionary<String, Object>;
    }

    // The text of candidates[0].content.parts[0].text, cleaned up for the screen, or null when
    // the answer does not have that shape or the text is empty. Never throws: any unexpected
    // answer means "use the static template".
    function parseResponse(response as Dictionary or String or Null) as String or Null {
        var candidates = field(response, "candidates");
        if (!(candidates instanceof Array) || candidates.size() == 0) {
            return null;
        }
        var parts = field(field(candidates[0] as Object or Null, "content"), "parts");
        if (!(parts instanceof Array) || parts.size() == 0) {
            return null;
        }
        var text = field(parts[0] as Object or Null, "text");
        return text instanceof String ? clean(text) : null;
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
