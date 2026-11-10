package com.elderguard.ai.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R

object SosScreenTags {
    const val SCREEN = "sosScreen"
    const val CANCEL = "sosCancel"
}

/**
 * Full-screen red overlay shown while SOS is active: "Pidiendo ayuda…" and a large cancel
 * button, like the web app's SOS screen. It covers and blocks the watchface underneath.
 */
@Composable
fun SosScreen(onCancel: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(WatchColors.Danger)
            // Takes every touch, so nothing behind the overlay can be pressed or scrolled.
            .pointerInput(Unit) {}
            .padding(horizontal = 16.dp)
            .testTag(SosScreenTags.SCREEN),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
    ) {
        Text(
            text = stringResource(R.string.sos_active),
            color = WatchColors.OnDanger,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.title1,
            fontWeight = FontWeight.Bold,
            // Screen readers announce it as soon as the screen appears.
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        )
        Button(
            onClick = onCancel,
            modifier = Modifier.fillMaxWidth(0.8f).height(60.dp).testTag(SosScreenTags.CANCEL),
            shape = RoundedCornerShape(30.dp),
            // White on red: inverted from the screen, so the only action stands out.
            colors = ButtonDefaults.buttonColors(
                backgroundColor = WatchColors.OnDanger,
                contentColor = WatchColors.Danger,
            ),
            border = ButtonDefaults.buttonBorder(borderStroke = BorderStroke(2.dp, WatchColors.OnDanger)),
        ) {
            Text(
                text = stringResource(R.string.sos_cancel),
                style = MaterialTheme.typography.title2,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}
