package com.elderguard.ai.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.elderguard.ai.R
import com.elderguard.ai.telemetry.Gps
import java.util.Locale

private const val COORDINATE_DECIMALS = 5

/**
 * A coordinate with 5 decimals (about 1 m), like toFixed(5) in the web app. Always with a dot,
 * whatever the language, since coordinates are read and typed that way.
 */
fun formatCoordinate(degrees: Double): String = String.format(Locale.ROOT, "%.${COORDINATE_DECIMALS}f", degrees)

/**
 * Port of src/ui/alertLocation.js: where an alert says the person is, which may only be the last
 * position known when the signal was lost.
 */
@Composable
fun alertLocationText(gps: Gps): String = stringResource(
    if (gps.signal) R.string.sos_location else R.string.sos_last_location,
    formatCoordinate(gps.lat),
    formatCoordinate(gps.lng),
)
