package com.elderguard.ai.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.config.SosConfig
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Share of the list width the button takes; about 140 dp across on a small round watch. */
private const val SOS_WIDTH_FRACTION = 0.75f
private val RING_WIDTH = 6.dp
private val RING_GAP = 2.dp

object SosButtonTags {
    const val BUTTON = "sosButton"
    const val PROGRESS = "sosProgress"
    const val HINT = "sosHint"
}

/**
 * The large red SOS button: phone icon, "SOS" and "AUXILIO", like the web app's bottom zone.
 *
 * A tap does nothing. Holding it for [SosConfig.HOLD_DURATION_MS] fills a ring around it and then
 * calls [onActivate], without waiting for the finger to lift. Letting go earlier cancels and
 * shows "Mantén presionado" for a moment. A touch that turns into a scroll cancels silently.
 *
 * Built on a Box with button semantics rather than Material's Button, because Button's own click
 * handling would compete with this long-press gesture.
 */
@Composable
fun SosButton(onActivate: () -> Unit, modifier: Modifier = Modifier) {
    val description = stringResource(R.string.sos_hint, SosConfig.HOLD_DURATION_MS / 1000)
    val haptics = LocalHapticFeedback.current
    // The latest callback, even though the gesture below is set up only once.
    val currentOnActivate by rememberUpdatedState(onActivate)
    // From 0 to 1 while held. Animatable runs on the frame clock, which UI tests control.
    val progress = remember { Animatable(0f) }
    // 0 hides the hint; each short press increases it, restarting the timer that hides it.
    var hintRequest by remember { mutableIntStateOf(0) }

    LaunchedEffect(hintRequest) {
        if (hintRequest > 0) {
            delay(SosConfig.HOLD_HINT_DURATION_MS)
            hintRequest = 0
        }
    }

    Box(
        modifier = modifier.fillMaxWidth(SOS_WIDTH_FRACTION).aspectRatio(1f),
        contentAlignment = Alignment.Center,
    ) {
        if (progress.value > 0f) {
            CircularProgressIndicator(
                progress = progress.value,
                modifier = Modifier.fillMaxSize().testTag(SosButtonTags.PROGRESS),
                startAngle = 270f,
                endAngle = 270f,
                indicatorColor = WatchColors.Text,
                trackColor = Color.Transparent,
                strokeWidth = RING_WIDTH,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(RING_WIDTH + RING_GAP)
                .clip(CircleShape)
                .background(WatchColors.Danger)
                .border(width = 3.dp, color = WatchColors.DangerBorder, shape = CircleShape)
                .pointerInput(Unit) {
                    detectTapGestures(
                        onPress = {
                            hintRequest = 0
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            var activated = false
                            coroutineScope {
                                val hold = launch {
                                    progress.animateTo(
                                        targetValue = 1f,
                                        animationSpec = tween(SosConfig.HOLD_DURATION_MS, easing = LinearEasing),
                                    )
                                    activated = true
                                    progress.snapTo(0f)
                                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                    currentOnActivate()
                                }
                                // True when the finger lifts, false when a scroll takes the gesture.
                                val released = tryAwaitRelease()
                                if (!activated) {
                                    hold.cancel()
                                    progress.snapTo(0f)
                                    if (released) hintRequest++
                                }
                            }
                        },
                    )
                }
                // Before clearAndSetSemantics, which would otherwise clear the tag too.
                .testTag(SosButtonTags.BUTTON)
                // Read as one button with instructions, instead of three separate labels.
                .clearAndSetSemantics {
                    contentDescription = description
                    role = Role.Button
                },
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Call,
                    contentDescription = null,
                    tint = WatchColors.OnDanger,
                    modifier = Modifier.size(28.dp),
                )
                Text(
                    text = stringResource(R.string.sos_title),
                    color = WatchColors.OnDanger,
                    style = MaterialTheme.typography.display2,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = stringResource(R.string.sos_label),
                    color = WatchColors.OnDanger,
                    style = MaterialTheme.typography.title3,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        if (hintRequest > 0) {
            Text(
                text = stringResource(R.string.sos_hold_hint),
                color = WatchColors.Text,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.title3,
                modifier = Modifier
                    .background(WatchColors.Background, RoundedCornerShape(12.dp))
                    .border(1.dp, WatchColors.Text, RoundedCornerShape(12.dp))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
                    // Screen readers announce it when it appears, like the web app's announcer.
                    .semantics { liveRegion = LiveRegionMode.Polite }
                    .testTag(SosButtonTags.HINT),
            )
        }
    }
}
