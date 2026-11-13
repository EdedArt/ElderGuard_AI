import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// A 12-hour reading, for example "9:05" and pm = true. The period label comes from the strings.
class ClockTime {
    var time as String;
    var pm as Boolean;

    function initialize(time as String, pm as Boolean) {
        self.time = time;
        self.pm = pm;
    }
}

// Port of src/core/timeFormat.js (TimeFormat.kt in wear-app). The format functions are pure:
// they take the time as parameters, so tests do not depend on the clock. now() and today() read
// the watch's clock and turn it into text in the app language.
module TimeFormat {
    // 12-hour time in every language, matching the other apps: no leading zero on the hour.
    function formatTime(hour as Number, minute as Number) as ClockTime {
        var hour12 = hour % 12;
        return new ClockTime((hour12 == 0 ? 12 : hour12) + ":" + minute.format("%02d"), hour >= 12);
    }

    // "a. m." / "p. m." in Spanish, "AM" / "PM" in English.
    function periodLabel(clock as ClockTime, language as LanguagePreference) as String {
        return clock.pm
            ? language.text(Rez.Strings.ClockPm, Rez.Strings.ClockPmEn)
            : language.text(Rez.Strings.ClockAm, Rez.Strings.ClockAmEn);
    }

    // Short weekday, day and month, for example "dom, 8 nov" or "Sun, Nov 8", like
    // Intl.DateTimeFormat in the web app. weekday goes from 1 (Sunday) to 7 and month from 1 to
    // 12, as Gregorian.info returns them with FORMAT_SHORT.
    function formatShortDate(weekday as Number, day as Number, month as Number, language as LanguagePreference) as String {
        var weekdays = language.text(Rez.Strings.WeekdaysShort, Rez.Strings.WeekdaysShortEn);
        var months = language.text(Rez.Strings.MonthsShort, Rez.Strings.MonthsShortEn);
        return Lang.format(language.text(Rez.Strings.DateFormat, Rez.Strings.DateFormatEn), [
            listItem(weekdays, weekday - 1),
            day,
            listItem(months, month - 1),
        ]);
    }

    function now() as ClockTime {
        var clock = System.getClockTime();
        return formatTime(clock.hour, clock.min);
    }

    function today(language as LanguagePreference) as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return formatShortDate(info.day_of_week as Number, info.day, info.month as Number, language);
    }

    // The item at index (from 0) of a comma-separated list such as "dom,lun,mar".
    function listItem(list as String, index as Number) as String {
        var rest = list;
        for (var i = 0; i < index; i++) {
            var comma = rest.find(",");
            if (comma == null) {
                return "";
            }
            rest = rest.substring(comma + 1, null) as String;
        }
        var end = rest.find(",");
        return end == null ? rest : rest.substring(0, end) as String;
    }
}
