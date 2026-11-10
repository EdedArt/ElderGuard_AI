package com.elderguard.ai.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.telemetry.Battery
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.HeartRate
import kotlin.math.roundToInt

/** Battery icon and percentage. */
@Composable
fun BatteryIndicator(battery: Battery, modifier: Modifier = Modifier) {
    val percent = battery.level.roundToInt()
    val description = stringResource(R.string.battery_label, percent)
    val color = MaterialTheme.colors.onBackground
    Row(
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        BatteryIcon(fraction = percent / 100f, color = color)
        Text(text = stringResource(R.string.battery_value, percent), color = color, style = MaterialTheme.typography.title3)
    }
}

/** GPS icon with "GPS" or "Sin GPS". */
@Composable
fun GpsIndicator(gps: Gps, modifier: Modifier = Modifier) {
    val description = stringResource(if (gps.signal) R.string.gps_ok_label else R.string.gps_lost_label)
    val color = MaterialTheme.colors.onBackground
    Row(
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Icon(imageVector = Icons.Filled.LocationOn, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        Text(
            text = stringResource(if (gps.signal) R.string.gps_ok else R.string.gps_lost),
            color = color,
            style = MaterialTheme.typography.title3,
        )
    }
}

/** Heart icon with the BPM in large digits. */
@Composable
fun HeartRateIndicator(heartRate: HeartRate, modifier: Modifier = Modifier) {
    val description = stringResource(R.string.heart_rate_label, heartRate.bpm)
    Row(
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = description },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Favorite,
            contentDescription = null,
            tint = MaterialTheme.colors.onBackground,
            modifier = Modifier.size(28.dp),
        )
        Text(text = heartRate.bpm.toString(), style = MaterialTheme.typography.display2)
        Text(text = stringResource(R.string.heart_rate_unit), style = MaterialTheme.typography.title3)
    }
}

/** A battery outline filled up to [fraction]. Material's core icons have no battery. */
@Composable
private fun BatteryIcon(fraction: Float, color: Color) {
    Canvas(modifier = Modifier.size(width = 24.dp, height = 14.dp)) {
        val stroke = 2.dp.toPx()
        val capWidth = 3.dp.toPx()
        val bodyWidth = size.width - capWidth
        drawRoundRect(
            color = color,
            topLeft = Offset(stroke / 2, stroke / 2),
            size = Size(bodyWidth - stroke, size.height - stroke),
            cornerRadius = CornerRadius(2.dp.toPx()),
            style = Stroke(width = stroke),
        )
        drawRect(
            color = color,
            topLeft = Offset(bodyWidth, size.height / 3),
            size = Size(capWidth, size.height / 3),
        )
        val inset = stroke * 1.75f
        drawRect(
            color = color,
            topLeft = Offset(inset, inset),
            size = Size((bodyWidth - inset * 2) * fraction.coerceIn(0f, 1f), size.height - inset * 2),
        )
    }
}
