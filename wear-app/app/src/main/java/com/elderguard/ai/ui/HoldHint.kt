package com.elderguard.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.config.SosConfig
import kotlinx.coroutines.delay

const val HOLD_HINT_TAG = "holdHint"

private val HINT_SHAPE = RoundedCornerShape(12.dp)

/** Whether the "Mantén presionado" hint is showing. Port of src/ui/holdHint.js. */
@Stable
class HoldHintState {
    // 0 hides the hint; each show() increases it, which restarts the timer that hides it.
    internal var request by mutableIntStateOf(0)
        private set

    val isVisible: Boolean
        get() = request > 0

    fun show() {
        request++
    }

    fun hide() {
        request = 0
    }
}

@Composable
fun rememberHoldHintState(): HoldHintState = remember { HoldHintState() }

/**
 * Tells the user that SOS needs a long press, for [SosConfig.HOLD_HINT_DURATION_MS] after a press
 * that was too short. Placed by the caller at a fixed spot on the screen, so it stays visible
 * wherever the SOS button is scrolled to, and is never hidden under the finger.
 */
@Composable
fun HoldHint(state: HoldHintState, modifier: Modifier = Modifier) {
    LaunchedEffect(state.request) {
        if (state.isVisible) {
            delay(SosConfig.HOLD_HINT_DURATION_MS)
            state.hide()
        }
    }
    if (state.isVisible) {
        Text(
            text = stringResource(R.string.sos_hold_hint),
            color = WatchColors.Text,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.title3,
            modifier = modifier
                .background(WatchColors.Background, HINT_SHAPE)
                .border(1.dp, WatchColors.Text, HINT_SHAPE)
                .padding(horizontal = 10.dp, vertical = 6.dp)
                // Screen readers announce it when it appears, like the web app's announcer.
                .semantics { liveRegion = LiveRegionMode.Polite }
                .testTag(HOLD_HINT_TAG),
        )
    }
}
