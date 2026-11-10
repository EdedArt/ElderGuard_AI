package com.elderguard.ai.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryState

/**
 * Everything on the watch screen. Stateless: it draws [state] and reports actions through the
 * callbacks, so UI tests can drive it without the simulation engine.
 */
@Composable
fun WatchApp(
    state: TelemetryState,
    onSosActivate: () -> Unit,
    onSosCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier.fillMaxSize()) {
        Watchface(state = state, onSosActivate = onSosActivate)
        if (state.deviceStatus.mode == DeviceMode.Sos) {
            SosScreen(onCancel = onSosCancel)
        }
    }
}
