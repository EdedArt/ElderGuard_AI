package com.elderguard.ai.device

import com.elderguard.ai.alerts.Countdown
import com.elderguard.ai.alerts.FallMonitor
import com.elderguard.ai.alerts.HeartRateMonitor
import com.elderguard.ai.alerts.SosController
import com.elderguard.ai.alerts.SosReason
import com.elderguard.ai.telemetry.SimulationEngine
import com.elderguard.ai.telemetry.TelemetryStore
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope

/**
 * Port of src/core/device.js: everything the watch runs on, wired together, with no user
 * interface. Every coroutine runs in [scope], so cancelling it stops the whole device.
 *
 * The ViewModel builds one in viewModelScope; UI tests build one in the composition's scope, so
 * the test clock drives the ticks, the detection and the countdown alike.
 */
class WatchDevice(
    scope: CoroutineScope,
    now: () -> Long = System::currentTimeMillis,
    random: Random = Random,
) {
    val store = TelemetryStore()
    val engine = SimulationEngine(store, scope, random, now)
    val sos = SosController(store, now)
    val countdown = Countdown(scope)
    val fall = FallMonitor(
        store = store,
        countdown = countdown,
        scope = scope,
        now = now,
        onCountdownComplete = { sos.trigger(SosReason.Fall) },
    )
    val heartRate = HeartRateMonitor(store, scope, now)

    fun start() {
        engine.start()
    }
}
