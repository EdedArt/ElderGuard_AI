package com.elderguard.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Call
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.config.SosConfig

/** Share of the list width the button takes; about 140 dp across on a small round watch. */
private const val SOS_WIDTH_FRACTION = 0.75f

/**
 * The large red SOS button: phone icon, "SOS" and "AUXILIO", like the web app's bottom zone.
 *
 * Built on a Box with button semantics rather than Material's Button, because Button's own click
 * handling would compete with the long-press gesture that activates SOS.
 */
@Composable
fun SosButton(modifier: Modifier = Modifier) {
    val description = stringResource(R.string.sos_hint, SosConfig.HOLD_DURATION_MS / 1000)
    Box(
        modifier = modifier
            .fillMaxWidth(SOS_WIDTH_FRACTION)
            .aspectRatio(1f)
            .clip(CircleShape)
            .background(WatchColors.Danger)
            .border(width = 3.dp, color = WatchColors.DangerBorder, shape = CircleShape)
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
}
