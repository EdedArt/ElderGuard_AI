package com.elderguard.ai.ui

import androidx.annotation.StringRes
import com.elderguard.ai.R
import com.elderguard.ai.language.AppLanguage
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter

// Port of src/core/timeFormat.js. Pure functions: they take the time and language as parameters
// and never read the clock or the watch's locale.

/** Morning or afternoon. The label comes from the string resources of the app language. */
enum class Period(@StringRes val label: Int) {
    Am(R.string.clock_am),
    Pm(R.string.clock_pm),
}

/** A 12-hour reading, for example "9:05" and [Period.Pm]. */
data class ClockTime(val time: String, val period: Period)

/** 12-hour time in every language, matching the web app: no leading zero on the hour. */
fun formatTime(time: LocalTime): ClockTime {
    val hour = time.hour % 12
    val minutes = time.minute.toString().padStart(2, '0')
    return ClockTime(
        time = "${if (hour == 0) 12 else hour}:$minutes",
        period = if (time.hour < 12) Period.Am else Period.Pm,
    )
}

// Weekday, day and month in each language's usual order, like Intl.DateTimeFormat in the web app.
private val shortDatePatterns = mapOf(
    AppLanguage.Es to "EEE, d MMM",
    AppLanguage.En to "EEE, MMM d",
)

/** Short weekday, day and month in the app language, for example "dom, 8 nov" or "Sun, Nov 8". */
fun formatShortDate(date: LocalDate, language: AppLanguage): String =
    DateTimeFormatter.ofPattern(shortDatePatterns.getValue(language), language.locale).format(date)
