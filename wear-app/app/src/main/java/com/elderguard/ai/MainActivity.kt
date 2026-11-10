package com.elderguard.ai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.language.LanguageRepository
import com.elderguard.ai.language.SharedPreferencesLanguageStorage
import com.elderguard.ai.ui.ProvideAppLanguage
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.TelemetryViewModel
import kotlin.math.roundToInt

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
        val languageState = languageRepository.language
        // setContent replaces setContentView with an XML layout: the screen is described in code.
        // The braces are a lambda passed as the last argument, like `setContent(() -> { ... })`.
        setContent {
            // Turns the StateFlow into Compose state: every new value redraws the readout.
            // It stops collecting while the app is in the background.
            val state by telemetryState.collectAsStateWithLifecycle()
            val language by languageState.collectAsStateWithLifecycle()
            ProvideAppLanguage(language) {
                ElderGuardApp(state)
            }
        }
    }
}

// A @Composable function describes part of the UI. Compose calls it again whenever the data it
// reads changes, so there is no manual view updating as with findViewById.
@Composable
fun ElderGuardApp(state: TelemetryState) {
    MaterialTheme {
        TelemetryReadout(state)
    }
}

// Temporary live readout, like the one the web app had before its watchface. Replaced in N3.
@Composable
fun TelemetryReadout(state: TelemetryState) {
    // Column stacks its children vertically, centered on the round screen.
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Strings from res/values (Spanish) and res/values-en (English), filled in like String.format.
        Text(
            text = stringResource(R.string.readout_heart_rate, state.heartRate.bpm),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.display3,
        )
        Text(
            text = stringResource(R.string.readout_battery, state.battery.level.roundToInt()),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.title2,
        )
        Text(
            text = stringResource(R.string.readout_movement, state.accelerometer.magnitude),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.title2,
        )
    }
}

// Shown in the Android Studio design pane on a round watch, without running the emulator.
@Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
@Composable
fun ElderGuardAppPreview() {
    ElderGuardApp(TelemetryState.initial())
}
