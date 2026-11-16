import Toybox.Lang;

// How the app asks Gemini (Google AI) for the text of an alert. The key is not here: it lives in
// source/Secrets.mc (GEMINI_API_KEY), which git ignores.
module GeminiConfig {
    // gemini-2.0-flash was shut down on 1 June 2026 and now answers 404. The lite model answers in
    // about 2 seconds, well inside the timeout.
    const MODEL = "gemini-3.5-flash-lite";
    const ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/";

    // How long the alert waits for Gemini before falling back to the static template.
    const TIMEOUT_MS = 8000;

    // A cap on the answer, so it stays short and small in the watch's memory. Two sentences take
    // about 50 tokens.
    const MAX_OUTPUT_TOKENS = 120;
}
