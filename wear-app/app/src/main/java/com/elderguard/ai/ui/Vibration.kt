package com.elderguard.ai.ui

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Vibrates for [millis] if the watch can. Port of src/ui/vibrate.js: vibration is a helpful extra,
 * so a missing vibrator, a missing permission or any other failure is ignored.
 */
fun vibrate(context: Context, millis: Long) {
    try {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            // Replaced by VibratorManager in Android 12, but the only way before it.
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
        if (vibrator?.hasVibrator() == true) {
            vibrator.vibrate(VibrationEffect.createOneShot(millis, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    } catch (_: Exception) {
        // No vibration: the countdown on screen still says everything.
    }
}
