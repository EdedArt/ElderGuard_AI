package com.elderguard.ai.ui

import com.elderguard.ai.language.AppLanguage
import java.time.LocalDate
import java.time.LocalTime
import org.junit.Assert.assertEquals
import org.junit.Test

class TimeFormatTest {
    @Test
    fun usesTwelveHourTimeWithoutALeadingZero() {
        assertEquals(ClockTime("9:05", Period.Am), formatTime(LocalTime.of(9, 5)))
        assertEquals(ClockTime("9:05", Period.Pm), formatTime(LocalTime.of(21, 5)))
    }

    @Test
    fun showsMidnightAndNoonAsTwelve() {
        assertEquals(ClockTime("12:00", Period.Am), formatTime(LocalTime.MIDNIGHT))
        assertEquals(ClockTime("12:00", Period.Pm), formatTime(LocalTime.NOON))
    }

    @Test
    fun switchesPeriodAtNoon() {
        assertEquals(Period.Am, formatTime(LocalTime.of(11, 59)).period)
        assertEquals(Period.Pm, formatTime(LocalTime.of(12, 0)).period)
        assertEquals(Period.Pm, formatTime(LocalTime.of(23, 59)).period)
    }

    @Test
    fun padsMinutesToTwoDigits() {
        assertEquals("1:00", formatTime(LocalTime.of(1, 0)).time)
        assertEquals("10:30", formatTime(LocalTime.of(22, 30)).time)
    }

    @Test
    fun formatsTheShortDateInSpanish() {
        assertEquals("dom, 8 nov", formatShortDate(LocalDate.of(2026, 11, 8), AppLanguage.Es))
    }

    @Test
    fun formatsTheShortDateInEnglish() {
        assertEquals("Sun, Nov 8", formatShortDate(LocalDate.of(2026, 11, 8), AppLanguage.En))
    }
}
