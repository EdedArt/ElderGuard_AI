import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// The languages of the app. Spanish is the default, whatever the language of the watch.
enum AppLanguage {
    LANGUAGE_ES,
    LANGUAGE_EN,
}

// Where the chosen language is saved: Application.Storage, the Connect IQ key-value store that
// survives restarts (API 2.4+). A class of its own so tests can replace it with one that fails.
class LanguageStorage {
    const KEY = "language";

    function initialize() {
    }

    // The saved tag ("es" or "en"), or null if nothing valid was saved.
    function read() as String or Null {
        var value = Storage.getValue(KEY);
        return value instanceof String ? value : null;
    }

    function write(tag as String) as Void {
        Storage.setValue(KEY, tag);
    }
}

// The language chosen by the user, saved across restarts. Port of LanguageRepository.kt in
// wear-app. Starts in Spanish unless English was saved; the language of the watch is never used.
// Storage failures never crash the app: a failed read falls back to Spanish, and a failed write
// still changes the language until the app closes.
//
// Connect IQ picks string resources by the watch's language only (resources-eng and so on), so
// both languages are compiled into the default resources: Spanish strings in
// resources/strings/strings.xml and their English versions, with the same id plus "En", in
// resources/strings/strings-eng.xml. text() loads the one for the current language.
class LanguagePreference {
    private var _storage as LanguageStorage;
    private var _language as AppLanguage;

    function initialize(storage as LanguageStorage) {
        _storage = storage;
        _language = readSaved();
    }

    function getLanguage() as AppLanguage {
        return _language;
    }

    function setLanguage(language as AppLanguage) as Void {
        _language = language;
        try {
            _storage.write(tagOf(language));
        } catch (e) {
            // Not saved: the change still applies for this session.
        }
    }

    // The string for the current language, for example text(Rez.Strings.SosTitle, Rez.Strings.SosTitleEn).
    // Taking both ids means every call site needs both languages to compile.
    function text(spanish as ResourceId, english as ResourceId) as String {
        return WatchUi.loadResource(_language == LANGUAGE_EN ? english : spanish) as String;
    }

    static function tagOf(language as AppLanguage) as String {
        return language == LANGUAGE_EN ? "en" : "es";
    }

    // The language with this tag, or null for an unknown or missing tag.
    static function fromTag(tag as String or Null) as AppLanguage or Null {
        if (tag != null && tag.equals("es")) {
            return LANGUAGE_ES;
        }
        if (tag != null && tag.equals("en")) {
            return LANGUAGE_EN;
        }
        return null;
    }

    private function readSaved() as AppLanguage {
        var saved = null;
        try {
            saved = fromTag(_storage.read());
        } catch (e) {
            // Unreadable storage: use the default.
        }
        return saved != null ? saved : LANGUAGE_ES;
    }
}
