package com.elderguard.ai.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import com.elderguard.ai.telemetry.TelemetryState

/** Test tags, so UI tests can find each part of the watchface. */
object WatchfaceTags {
    const val CLOCK = "clock"
    const val BATTERY = "battery"
    const val GPS = "gps"
    const val HEART_RATE = "heartRate"
    const val HEART_RATE_BANNER = "heartRateBanner"
    const val SOS = "sos"
    const val LIST = "watchfaceList"
}

// Item positions in the list. The clock is the item centered on the screen at start.
private const val CLOCK_ITEM = 1

// Low enough to clear the curved edge of a round screen at its widest text.
private val HINT_TOP_PADDING = 28.dp

/**
 * The main screen, mirroring the three zones of the web watchface from top to bottom: status
 * (battery and GPS), data (clock and heart rate) and the SOS area.
 *
 * A round 1.2-inch screen cannot fit all of it at a readable size, so it is a ScalingLazyColumn:
 * the Wear OS list that scrolls with the crown or a swipe and shrinks items near the curved edges.
 */
@Composable
fun Watchface(
    state: TelemetryState,
    modifier: Modifier = Modifier,
    onSosActivate: () -> Unit = {},
    criticalHeartRate: Boolean = false,
) {
    val listState = rememberScalingLazyListState()
    val holdHint = rememberHoldHintState()
    // The large clock already shows the time; the small curved one appears once it scrolls away.
    val clockVisible by remember {
        derivedStateOf { listState.layoutInfo.visibleItemsInfo.any { it.index == CLOCK_ITEM } }
    }

    // Scaffold places the standard Wear OS elements around the content: the time at the top and
    // the scroll position indicator at the right edge.
    Scaffold(
        modifier = modifier,
        timeText = { if (!clockVisible) TimeText(timeSource = AppTimeSource) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            ScalingLazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize().testTag(WatchfaceTags.LIST),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        BatteryIndicator(state.battery, Modifier.testTag(WatchfaceTags.BATTERY))
                        GpsIndicator(state.gps, Modifier.testTag(WatchfaceTags.GPS))
                    }
                }
                item { WatchClock(Modifier.testTag(WatchfaceTags.CLOCK)) }
                // Right under the clock, like the web app, so it shows on the opening screen.
                // Always an item, even when empty, so the item positions above never shift.
                item {
                    HeartRateBanner(
                        healthAlert = state.deviceStatus.healthAlert,
                        critical = criticalHeartRate,
                        modifier = Modifier.testTag(WatchfaceTags.HEART_RATE_BANNER),
                    )
                }
                item { HeartRateIndicator(state.heartRate, Modifier.testTag(WatchfaceTags.HEART_RATE)) }
                item {
                    SosButton(
                        onActivate = onSosActivate,
                        onHoldStart = holdHint::hide,
                        onShortPress = holdHint::show,
                        modifier = Modifier.testTag(WatchfaceTags.SOS),
                    )
                }
            }
            // Outside the list, at a fixed spot inside the round safe area: visible however far
            // the list is scrolled, and away from the finger on the SOS button.
            HoldHint(state = holdHint, modifier = Modifier.align(Alignment.TopCenter).padding(top = HINT_TOP_PADDING))
        }
    }
}
