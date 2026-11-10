package com.elderguard.ai.telemetry

import com.elderguard.ai.config.TelemetryConfig
import kotlin.math.roundToInt

// Port of batteryPercent, batteryState and gpsState from src/core/watchStatus.js.

enum class BatteryState { Normal, Low, Critical }

enum class GpsState { Ok, Lost }

/** The whole percentage shown on the watch. Rounds half up, like Math.round in the web app. */
fun batteryPercent(level: Double): Int = level.roundToInt()

/** Critical at 10 % or less, low at 20 % or less, normal above. Both thresholds are inclusive. */
fun batteryState(level: Double): BatteryState = when {
    level <= TelemetryConfig.Battery.CRITICAL_LEVEL -> BatteryState.Critical
    level <= TelemetryConfig.Battery.LOW_LEVEL -> BatteryState.Low
    else -> BatteryState.Normal
}

/** The state of the battery as displayed: computed from the rounded percentage, like the web app. */
val Battery.displayState: BatteryState
    get() = batteryState(batteryPercent(level).toDouble())

fun gpsState(gps: Gps): GpsState = if (gps.signal) GpsState.Ok else GpsState.Lost
