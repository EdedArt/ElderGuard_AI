package com.elderguard.ai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
 *
 * When the rate is [critical], the banner turns red and says the family was told: a critical
 * alert has no screen of its own, so this is the only place where the wearer learns it went out.
 * Draws nothing when there is no warning.
 */
@Composable
fun HeartRateBanner(healthAlert: HealthAlert?, modifier: Modifier = Modifier, critical: Boolean = false) {
    val text = when {
        critical -> stringResource(R.string.heart_rate_alert_critical)
        healthAlert == HealthAlert.HighHeartRate -> stringResource(R.string.heart_rate_alert_high)
        else -> return
    }
    val fill = if (critical) WatchColors.Danger else WatchColors.Warning
    val content = if (critical) WatchColors.OnDanger else WatchColors.OnWarning
    Row(
        modifier = modifier
            .widthIn(max = BANNER_MAX_WIDTH)
            .background(fill, BANNER_SHAPE)
            // The dark red alone is hard to tell apart from black, as on the SOS button.
            .then(if (critical) Modifier.border(2.dp, WatchColors.DangerBorder, BANNER_SHAPE) else Modifier)
            .padding(horizontal = 10.dp, vertical = 6.dp)
            // Read as one message, announced when it appears.
            .semantics(mergeDescendants = true) {
                liveRegion = LiveRegionMode.Polite
                statusColor = fill
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = content,
            modifier = Modifier.size(20.dp),
        )
        Text(
            text = text,
            color = content,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.caption1,
            fontWeight = FontWeight.Bold,
        )
    }
}
