package com.elderguard.ai.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.config.FallDetectionConfig

object FallCountdownTags {
    const val SCREEN = "fallCountdown"
    const val SECONDS = "fallCountdownSeconds"
    const val RING = "fallCountdownRing"
    const val CANCEL = "fallCancel"
}

private const val VIBRATION_PER_SECOND_MS = 200L
private const val TICK_MS = 1000
private const val TRACK_ALPHA = 0.3f
private val RING_WIDTH = 6.dp

/** How full the draining ring is, from 1 to 0. Exposed to UI tests, which cannot read pixels. */
val FallRingProgressKey = SemanticsPropertyKey<Float>("FallRingProgress")

/**
 * Full-watch overlay after a detected fall, like the web app's fall overlay: "¿Te caíste?", the
 * seconds left in large digits, a ring that drains with them and a huge "ESTOY BIEN" button.
 * Amber at first, red in the last [FallDetectionConfig.URGENT_SECONDS]. The watch vibrates on
 * every second. It covers and blocks the watchface underneath.
 */
@Composable
fun FallCountdownScreen(
    remainingSeconds: Int,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
    totalSeconds: Int = FallDetectionConfig.COUNTDOWN_SECONDS,
) {
    val urgent = remainingSeconds <= FallDetectionConfig.URGENT_SECONDS
    val surface = if (urgent) WatchColors.Danger else WatchColors.Warning
    val content = if (urgent) WatchColors.OnDanger else WatchColors.OnWarning
    val context = LocalContext.current
    val announcement = stringResource(R.string.fall_announce_start, totalSeconds)

    // Drains smoothly during each second toward the value at its end, so it empties at zero.
    val ring = remember { Animatable(remainingSeconds.toFloat() / totalSeconds) }
    LaunchedEffect(remainingSeconds) {
        if (remainingSeconds > 0) vibrate(context, VIBRATION_PER_SECOND_MS)
        val target = (remainingSeconds - 1).coerceAtLeast(0).toFloat() / totalSeconds
        ring.animateTo(target, tween(TICK_MS, easing = LinearEasing))
    }
    val progress = ring.value

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(surface)
            // Takes every touch, so nothing behind the overlay can be pressed or scrolled.
            .pointerInput(Unit) {}
            .testTag(FallCountdownTags.SCREEN),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(
            progress = progress,
            modifier = Modifier
                .fillMaxSize()
                .semantics { set(FallRingProgressKey, progress) }
                .testTag(FallCountdownTags.RING),
            startAngle = 270f,
            endAngle = 270f,
            indicatorColor = content,
            trackColor = content.copy(alpha = TRACK_ALPHA),
            strokeWidth = RING_WIDTH,
        )
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = stringResource(R.string.fall_question),
                color = content,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.title2,
                fontWeight = FontWeight.Bold,
                // Read once when the overlay appears, with what to do; the seconds are not read
                // one by one, which would talk over the wearer's answer.
                modifier = Modifier.semantics {
                    contentDescription = announcement
                    liveRegion = LiveRegionMode.Assertive
                },
            )
            Text(
                text = remainingSeconds.toString(),
                color = content,
                fontSize = 56.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.testTag(FallCountdownTags.SECONDS),
            )
            Button(
                onClick = onCancel,
                modifier = Modifier.fillMaxWidth(0.7f).height(56.dp).testTag(FallCountdownTags.CANCEL),
                shape = RoundedCornerShape(28.dp),
                // Black with a white outline, as in the web app's dark theme: stands out on amber and red.
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = WatchColors.Background,
                    contentColor = WatchColors.Text,
                ),
                border = ButtonDefaults.buttonBorder(borderStroke = BorderStroke(3.dp, WatchColors.Text)),
            ) {
                Text(
                    text = stringResource(R.string.fall_cancel),
                    style = MaterialTheme.typography.title2,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}
