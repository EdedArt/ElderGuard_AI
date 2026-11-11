package com.elderguard.ai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.MaterialTheme
import com.elderguard.ai.language.AppLanguage
import com.elderguard.ai.language.LanguageRepository
import com.elderguard.ai.language.SharedPreferencesLanguageStorage
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.TelemetryViewModel
import com.elderguard.ai.ui.ProvideAppLanguage
import com.elderguard.ai.ui.WatchApp

// Kotlin notes for Java developers:
// - `class MainActivity : ComponentActivity()` is `class MainActivity extends ComponentActivity`.
// - `override fun` is a method marked @Override; `fun` declares any function.
// - Types go after the name (`savedInstanceState: Bundle?`), and `?` means the value may be null.
class MainActivity : ComponentActivity() {
    // `by viewModels()` creates the ViewModel the first time it is read and returns the same one
    // after the activity is re-created.
    private val telemetry: TelemetryViewModel by viewModels()

    // `by lazy` creates it on first use. The language never restarts the activity, so one per
    // activity is enough.
    private val languageRepository by lazy {
        LanguageRepository(SharedPreferencesLanguageStorage(applicationContext))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Reading the ViewModel here creates it, which starts the simulation engine.
        val telemetryState = telemetry.state
        val fallCountdownState = telemetry.fallCountdown
        val criticalHeartRateState = telemetry.criticalHeartRate
        val languageState = languageRepository.language
        // setContent replaces setContentView with an XML layout: the screen is described in code.
        // The braces are a lambda passed as the last argument, like `setContent(() -> { ... })`.
        setContent {
            // Turns the StateFlow into Compose state: every new value redraws the screen.
            // It stops collecting while the app is in the background.
            val state by telemetryState.collectAsStateWithLifecycle()
            val fallCountdown by fallCountdownState.collectAsStateWithLifecycle()
            val criticalHeartRate by criticalHeartRateState.collectAsStateWithLifecycle()
            val language by languageState.collectAsStateWithLifecycle()
            ProvideAppLanguage(language) {
                // `telemetry::triggerSos` is a method reference, written the same way as in Java.
                ElderGuardApp(
                    state = state,
                    language = language,
                    onLanguageChange = languageRepository::setLanguage,
                    onSosActivate = telemetry::triggerSos,
                    onSosCancel = telemetry::cancelSos,
                    fallCountdownSeconds = fallCountdown,
                    onFallCancel = telemetry::cancelFall,
                    criticalHeartRate = criticalHeartRate,
                )
            }
        }
    }
}

// A @Composable function describes part of the UI. Compose calls it again whenever the data it
// reads changes, so there is no manual view updating as with findViewById.
@Composable
fun ElderGuardApp(
    state: TelemetryState,
    language: AppLanguage = AppLanguage.Default,
    onLanguageChange: (AppLanguage) -> Unit = {},
    onSosActivate: () -> Unit = {},
    onSosCancel: () -> Unit = {},
    fallCountdownSeconds: Int? = null,
    onFallCancel: () -> Unit = {},
    criticalHeartRate: Boolean = false,
) {
    // Wear OS's standard dark Material theme: a black background saves battery on OLED screens.
    MaterialTheme {
        WatchApp(
            state = state,
            language = language,
            onLanguageChange = onLanguageChange,
            onSosActivate = onSosActivate,
            onSosCancel = onSosCancel,
            fallCountdownSeconds = fallCountdownSeconds,
            onFallCancel = onFallCancel,
            criticalHeartRate = criticalHeartRate,
        )
    }
}

// Shown in the Android Studio design pane on a round watch, without running the emulator.
@Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
@Composable
fun ElderGuardAppPreview() {
    ElderGuardApp(TelemetryState.initial())
}
