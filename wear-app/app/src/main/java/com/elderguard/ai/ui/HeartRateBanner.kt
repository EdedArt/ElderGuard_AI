package com.elderguard.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.telemetry.HealthAlert

private val BANNER_SHAPE = RoundedCornerShape(12.dp)
private val BANNER_MAX_WIDTH = 160.dp

/**
 * Port of src/ui/heartRateBanner.js: an amber banner while a health warning is in progress. A
 * warning, not an alert: the wearer can read it and go on, and everything else keeps working.
 * Draws nothing when there is no warning.
 */
@Composable
fun HeartRateBanner(healthAlert: HealthAlert?, modifier: Modifier = Modifier) {
    if (healthAlert == null) return
    val text = when (healthAlert) {
        HealthAlert.HighHeartRate -> stringResource(R.string.heart_rate_alert_high)
    }
    Row(
        modifier = modifier
            .widthIn(max = BANNER_MAX_WIDTH)
            .background(WatchColors.Warning, BANNER_SHAPE)
            .padding(horizontal = 10.dp, vertical = 6.dp)
            // Read as one message, announced when it appears.
            .semantics(mergeDescendants = true) {
                liveRegion = LiveRegionMode.Polite
                statusColor = WatchColors.Warning
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = WatchColors.OnWarning,
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = text,
            color = WatchColors.OnWarning,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.caption1,
            fontWeight = FontWeight.Bold,
        )
    }
}
