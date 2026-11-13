import Toybox.Lang;
import Toybox.Test;

// Port of LanguageRepositoryTest.kt (wear-app) and the language cases of the web i18n tests.

// Storage kept in memory, standing in for Application.Storage.
(:test)
class MemoryLanguageStorage extends LanguageStorage {
    var saved as String or Null;

    function initialize(saved as String or Null) {
        LanguageStorage.initialize();
        self.saved = saved;
    }

    function read() as String or Null {
        return saved;
    }

    function write(tag as String) as Void {
        saved = tag;
    }
}

// Storage that fails on every call, like a full or corrupted store.
(:test)
class BrokenLanguageStorage extends LanguageStorage {
    function initialize() {
        LanguageStorage.initialize();
    }

    function read() as String or Null {
        throw new Lang.OperationNotAllowedException("Storage unavailable");
    }

    function write(tag as String) as Void {
        throw new Lang.OperationNotAllowedException("Storage unavailable");
    }
}

(:test)
function language_defaultsToSpanish(logger as Logger) as Boolean {
    return new LanguagePreference(new MemoryLanguageStorage(null)).getLanguage() == LANGUAGE_ES;
}

(:test)
function language_persistsAChangeAcrossRestarts(logger as Logger) as Boolean {
    var storage = new MemoryLanguageStorage(null);
    new LanguagePreference(storage).setLanguage(LANGUAGE_EN);
    Test.assertEqual("en", storage.saved);
    // A new preference over the same storage is the app opening again.
    return new LanguagePreference(storage).getLanguage() == LANGUAGE_EN;
}

(:test)
function language_changesRightAway(logger as Logger) as Boolean {
    var preference = new LanguagePreference(new MemoryLanguageStorage(null));
    preference.setLanguage(LANGUAGE_EN);
    Test.assert(preference.getLanguage() == LANGUAGE_EN);
    preference.setLanguage(LANGUAGE_ES);
    return preference.getLanguage() == LANGUAGE_ES;
}

(:test)
function language_fallsBackToSpanishWhenStorageIsUnavailable(logger as Logger) as Boolean {
    return new LanguagePreference(new BrokenLanguageStorage()).getLanguage() == LANGUAGE_ES;
}

(:test)
function language_stillChangesWhenSavingFails(logger as Logger) as Boolean {
    var preference = new LanguagePreference(new BrokenLanguageStorage());
    preference.setLanguage(LANGUAGE_EN);
    return preference.getLanguage() == LANGUAGE_EN;
}

(:test)
function language_fallsBackToSpanishForAnUnknownSavedValue(logger as Logger) as Boolean {
    return new LanguagePreference(new MemoryLanguageStorage("fr")).getLanguage() == LANGUAGE_ES;
}

(:test)
function language_mapsTagsToLanguages(logger as Logger) as Boolean {
    Test.assertEqual(LanguagePreference.tagOf(LANGUAGE_ES), "es");
    Test.assertEqual(LanguagePreference.tagOf(LANGUAGE_EN), "en");
    Test.assert(LanguagePreference.fromTag("es") == LANGUAGE_ES);
    Test.assert(LanguagePreference.fromTag("en") == LANGUAGE_EN);
    Test.assert(LanguagePreference.fromTag("EN") == null);
    Test.assert(LanguagePreference.fromTag(null) == null);
    return true;
}

(:test)
function language_loadsTheStringOfTheCurrentLanguage(logger as Logger) as Boolean {
    var preference = new LanguagePreference(new MemoryLanguageStorage(null));
    Test.assertEqual(preference.text(Rez.Strings.GpsLost, Rez.Strings.GpsLostEn), "Sin GPS");
    preference.setLanguage(LANGUAGE_EN);
    Test.assertEqual(preference.text(Rez.Strings.GpsLost, Rez.Strings.GpsLostEn), "No GPS");
    return true;
}

(:test)
function language_realStorageRoundTrips(logger as Logger) as Boolean {
    // Application.Storage in the simulator: saves, reads back and restores what was there.
    var storage = new LanguageStorage();
    var before = storage.read();
    storage.write("en");
    var ok = new LanguagePreference(storage).getLanguage() == LANGUAGE_EN;
    storage.write(before != null ? before : "es");
    return ok;
}
