import Toybox.Lang;
import Toybox.Test;

// The pure parts of GeminiService: the prompt, the request body and the reading of the answer.
// No network: requestAlertMessage() itself is checked by hand in the simulator (see README).

(:test)
class GeminiSamples {
    static const TIMESTAMP = 1763300000000l;

    static function gps() as Gps {
        return new Gps(4.6097d, -74.0817d, 3.0d, true);
    }

    static function lostGps() as Gps {
        return new Gps(4.6097d, -74.0817d, 3.0d, false);
    }

    // An answer as generateContent returns it.
    static function answer(text as Object or Null) as Dictionary {
        return {
            "candidates" => [{
                "content" => {"parts" => [{"text" => text}], "role" => "model"},
                "finishReason" => "STOP",
            }],
            "modelVersion" => GeminiConfig.MODEL,
        } as Dictionary;
    }

    static function contains(text as String, part as String) as Boolean {
        return text.find(part) != null;
    }
}

(:test)
function gemini_promptForAFallInSpanishCarriesTheReadings(logger as Logger) as Boolean {
    var prompt = GeminiService.buildAlertPrompt(ALERT_FALL, 92, GeminiSamples.TIMESTAMP, GeminiSamples.gps(), LANGUAGE_ES);
    Test.assert(GeminiSamples.contains(prompt, "en español"));
    Test.assert(GeminiSamples.contains(prompt, "caída confirmada"));
    Test.assert(GeminiSamples.contains(prompt, "Pulso: 92 LPM"));
    Test.assert(GeminiSamples.contains(prompt, "Hora: " + GeminiService.clockTime(GeminiSamples.TIMESTAMP)));
    Test.assert(GeminiSamples.contains(prompt, "4.60970, -74.08170 (GPS)"));
    Test.assert(GeminiSamples.contains(prompt, "Máximo 2 frases"));
    Test.assert(!GeminiSamples.contains(prompt, "$"));
    return true;
}

(:test)
function gemini_promptInEnglishIsWrittenInEnglish(logger as Logger) as Boolean {
    var prompt = GeminiService.buildAlertPrompt(ALERT_FALL, 92, GeminiSamples.TIMESTAMP, GeminiSamples.gps(), LANGUAGE_EN);
    Test.assert(GeminiSamples.contains(prompt, "in English"));
    Test.assert(GeminiSamples.contains(prompt, "confirmed fall"));
    Test.assert(GeminiSamples.contains(prompt, "Heart rate: 92 BPM"));
    Test.assert(GeminiSamples.contains(prompt, "At most 2 sentences"));
    Test.assert(!GeminiSamples.contains(prompt, "caída"));
    return true;
}

(:test)
function gemini_promptDescribesEachEvent(logger as Logger) as Boolean {
    var sos = GeminiService.buildAlertPrompt(ALERT_MANUAL_SOS, 80, GeminiSamples.TIMESTAMP, GeminiSamples.gps(), LANGUAGE_ES);
    var heart = GeminiService.buildAlertPrompt(ALERT_HIGH_HEART_RATE, 170, GeminiSamples.TIMESTAMP, GeminiSamples.gps(), LANGUAGE_EN);
    Test.assert(GeminiSamples.contains(sos, "botón SOS"));
    Test.assert(!GeminiSamples.contains(sos, "caída confirmada"));
    Test.assert(GeminiSamples.contains(heart, "critical heart rate at rest"));
    Test.assert(GeminiSamples.contains(heart, "170 BPM"));
    return true;
}

(:test)
function gemini_promptSaysWhenTheLocationIsTheLastKnown(logger as Logger) as Boolean {
    var es = GeminiService.buildAlertPrompt(ALERT_FALL, 92, GeminiSamples.TIMESTAMP, GeminiSamples.lostGps(), LANGUAGE_ES);
    var en = GeminiService.buildAlertPrompt(ALERT_FALL, 92, GeminiSamples.TIMESTAMP, GeminiSamples.lostGps(), LANGUAGE_EN);
    Test.assert(GeminiSamples.contains(es, "última posición conocida 4.60970, -74.08170"));
    Test.assert(GeminiSamples.contains(en, "last known position 4.60970, -74.08170"));
    return true;
}

(:test)
function gemini_clockTimeIsTwoDigitHoursAndMinutes(logger as Logger) as Boolean {
    var time = GeminiService.clockTime(GeminiSamples.TIMESTAMP);
    Test.assertEqual(time.length(), 5);
    Test.assertEqual(time.substring(2, 3) as String, ":");
    return true;
}

(:test)
function gemini_requestBodyHasContentsPartsText(logger as Logger) as Boolean {
    var body = GeminiService.buildRequestBody("Hola");
    var contents = body["contents"] as Array<Dictionary>;
    Test.assertEqual(contents.size(), 1);
    var parts = contents[0]["parts"] as Array<Dictionary>;
    Test.assertEqual(parts.size(), 1);
    Test.assertEqual(parts[0]["text"] as String, "Hola");
    var config = body["generationConfig"] as Dictionary;
    Test.assertEqual(config["maxOutputTokens"] as Number, GeminiConfig.MAX_OUTPUT_TOKENS);
    return true;
}

(:test)
function gemini_requestBodyKeepsTheWholePrompt(logger as Logger) as Boolean {
    var prompt = GeminiService.buildAlertPrompt(ALERT_FALL, 92, GeminiSamples.TIMESTAMP, GeminiSamples.gps(), LANGUAGE_ES);
    var body = GeminiService.buildRequestBody(prompt);
    var parts = (body["contents"] as Array<Dictionary>)[0]["parts"] as Array<Dictionary>;
    Test.assertEqual(parts[0]["text"] as String, prompt);
    return true;
}

(:test)
function gemini_urlNamesTheModelWithoutTheKey(logger as Logger) as Boolean {
    var url = GeminiService.url();
    Test.assertEqual(url,
        "https://generativelanguage.googleapis.com/v1beta/models/" + GeminiConfig.MODEL + ":generateContent");
    Test.assert(!GeminiSamples.contains(url, "key="));
    return true;
}

(:test)
function gemini_parseResponseReadsTheFirstCandidateText(logger as Logger) as Boolean {
    var text = "Ana, tu familiar sufrió una caída a las 15:07. Está en 4.60970, -74.08170.";
    Test.assertEqual(GeminiService.parseResponse(GeminiSamples.answer(text)) as String, text);
    return true;
}

(:test)
function gemini_parseResponseTrimsNewlinesSpacesAndQuotes(logger as Logger) as Boolean {
    Test.assertEqual(GeminiService.parseResponse(GeminiSamples.answer("  \"Caída detectada.\nLlama ya.\"\n")) as String,
        "Caída detectada. Llama ya.");
    return true;
}

(:test)
function gemini_parseResponseRejectsMalformedAnswers(logger as Logger) as Boolean {
    // What makeWebRequest passes when the body is not JSON, or there is no body at all.
    Test.assert(GeminiService.parseResponse("<html>502 Bad Gateway</html>") == null);
    Test.assert(GeminiService.parseResponse("{\"candidates\": [") == null);
    Test.assert(GeminiService.parseResponse(null) == null);
    return true;
}

(:test)
function gemini_parseResponseRejectsUnexpectedStructures(logger as Logger) as Boolean {
    // An API error, a blocked prompt and every level of the path missing or of the wrong type.
    Test.assert(GeminiService.parseResponse({"error" => {"code" => 404, "message" => "not found"}}) == null);
    Test.assert(GeminiService.parseResponse({"promptFeedback" => {"blockReason" => "SAFETY"}}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => []}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => "none"}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => [42]}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => [{"finishReason" => "SAFETY"}]}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => [{"content" => {"parts" => []}}]}) == null);
    Test.assert(GeminiService.parseResponse({"candidates" => [{"content" => {"parts" => [{"inlineData" => {}}]}}]}) == null);
    Test.assert(GeminiService.parseResponse(GeminiSamples.answer(7)) == null);
    Test.assert(GeminiService.parseResponse(GeminiSamples.answer(null)) == null);
    Test.assert(GeminiService.parseResponse(GeminiSamples.answer(" \n ")) == null);
    return true;
}
