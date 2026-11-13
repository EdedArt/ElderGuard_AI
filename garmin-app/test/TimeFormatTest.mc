import Toybox.Lang;
import Toybox.Test;

// Port of tests/timeFormat.test.js and TimeFormatTest.kt (wear-app).

(:test)
function time_usesTwelveHoursWithoutALeadingZero(logger as Logger) as Boolean {
    var clock = TimeFormat.formatTime(9, 5);
    Test.assertEqual(clock.time, "9:05");
    Test.assert(!clock.pm);
    clock = TimeFormat.formatTime(21, 30);
    Test.assertEqual(clock.time, "9:30");
    Test.assert(clock.pm);
    return true;
}

(:test)
function time_showsMidnightAndNoonAsTwelve(logger as Logger) as Boolean {
    var midnight = TimeFormat.formatTime(0, 0);
    Test.assertEqual(midnight.time, "12:00");
    Test.assert(!midnight.pm);
    var noon = TimeFormat.formatTime(12, 0);
    Test.assertEqual(noon.time, "12:00");
    Test.assert(noon.pm);
    return true;
}

(:test)
function time_handlesTheEdgesOfEachPeriod(logger as Logger) as Boolean {
    Test.assert(!TimeFormat.formatTime(11, 59).pm);
    var last = TimeFormat.formatTime(23, 59);
    Test.assertEqual(last.time, "11:59");
    Test.assert(last.pm);
    return true;
}

(:test)
function time_translatesThePeriod(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage(null));
    var am = TimeFormat.formatTime(9, 0);
    var pm = TimeFormat.formatTime(21, 0);
    Test.assertEqual(TimeFormat.periodLabel(am, language), "a. m.");
    Test.assertEqual(TimeFormat.periodLabel(pm, language), "p. m.");
    language.setLanguage(LANGUAGE_EN);
    Test.assertEqual(TimeFormat.periodLabel(am, language), "AM");
    Test.assertEqual(TimeFormat.periodLabel(pm, language), "PM");
    return true;
}

(:test)
function time_formatsTheShortDateInSpanish(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage(null));
    // Sunday 8 November 2026 and Wednesday 16 September 2026.
    Test.assertEqual(TimeFormat.formatShortDate(1, 8, 11, language), "dom, 8 nov");
    Test.assertEqual(TimeFormat.formatShortDate(4, 16, 9, language), "mié, 16 sept");
    return true;
}

(:test)
function time_formatsTheShortDateInEnglish(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage("en"));
    Test.assertEqual(TimeFormat.formatShortDate(1, 8, 11, language), "Sun, Nov 8");
    Test.assertEqual(TimeFormat.formatShortDate(7, 31, 12, language), "Sat, Dec 31");
    Test.assertEqual(TimeFormat.formatShortDate(2, 1, 1, language), "Mon, Jan 1");
    return true;
}

(:test)
function time_readsItemsOfACommaSeparatedList(logger as Logger) as Boolean {
    Test.assertEqual(TimeFormat.listItem("a,b,c", 0), "a");
    Test.assertEqual(TimeFormat.listItem("a,b,c", 2), "c");
    Test.assertEqual(TimeFormat.listItem("a,b,c", 3), "");
    return true;
}

(:test)
function time_readsTheWatchClock(logger as Logger) as Boolean {
    var clock = TimeFormat.now();
    logger.debug("now: " + clock.time + (clock.pm ? " pm" : " am"));
    return clock.time.length() >= 4 && clock.time.length() <= 5;
}
