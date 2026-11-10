package com.elderguard.ai.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeSource
import com.elderguard.ai.R
import java.time.Clock
import java.time.LocalDateTime
import kotlinx.coroutines.delay

private const val UPDATE_INTERVAL_MS = 1000L

/** The clock the watchface reads. Tests provide a fixed one to get a known time. */
val LocalClock = staticCompositionLocalOf<Clock> { Clock.systemDefaultZone() }

/** The current time, updated every second like the web app's clock. */
@Composable
fun rememberNow(): LocalDateTime {
    val clock = LocalClock.current
    var now by remember(clock) { mutableStateOf(LocalDateTime.now(clock)) }
    // LaunchedEffect runs a coroutine while this composable is on screen and cancels it after.
    LaunchedEffect(clock) {
        while (true) {
            delay(UPDATE_INTERVAL_MS)
            now = LocalDateTime.now(clock)
        }
    }
    return now
}

/** The text of a 12-hour time with its period in the app language, for example "9:05 p. m.". */
@Composable
fun clockText(now: LocalDateTime): String {
    val clockTime = formatTime(now.toLocalTime())
    return stringResource(R.string.clock_time_with_period, clockTime.time, stringResource(clockTime.period.label))
}

/**
 * Feeds TimeText (the curved time at the top of Wear OS screens) with the app's own format.
 * TimeText's default follows the watch's locale and 24-hour setting instead.
 */
object AppTimeSource : TimeSource {
    override val currentTime: String
        @Composable get() = clockText(rememberNow())
}

/** Large time with its period, and the short date below, like the center of the web watchface. */
@Composable
fun WatchClock(modifier: Modifier = Modifier) {
    val now = rememberNow()
    val clockTime = formatTime(now.toLocalTime())
    val description = stringResource(R.string.clock_label) + ", " + clockText(now) + ", " +
        formatShortDate(now.toLocalDate(), LocalAppLanguage.current)
    Column(
        // One node for screen readers, read as "Hora y fecha, 9:05 p. m., dom, 8 nov".
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = description },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.Center) {
            Text(text = clockTime.time, style = MaterialTheme.typography.display1)
            Text(
                text = stringResource(clockTime.period.label),
                style = MaterialTheme.typography.title3,
                modifier = Modifier.padding(start = 4.dp, bottom = 6.dp),
            )
        }
        Text(
            text = formatShortDate(now.toLocalDate(), LocalAppLanguage.current),
            style = MaterialTheme.typography.title3,
        )
    }
}
