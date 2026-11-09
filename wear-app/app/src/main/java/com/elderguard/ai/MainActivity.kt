package com.elderguard.ai

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text

// Kotlin notes for Java developers:
// - `class MainActivity : ComponentActivity()` is `class MainActivity extends ComponentActivity`.
// - `override fun` is a method marked @Override; `fun` declares any function.
// - Types go after the name (`savedInstanceState: Bundle?`), and `?` means the value may be null.
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // setContent replaces setContentView with an XML layout: the screen is described in code.
        // The braces are a lambda passed as the last argument, like `setContent(() -> { ... })`.
        setContent {
            ElderGuardApp()
        }
    }
}

// A @Composable function describes part of the UI. Compose calls it again whenever the data it
// reads changes, so there is no manual view updating as with findViewById.
@Composable
fun ElderGuardApp() {
    MaterialTheme {
        // Box stacks its children; contentAlignment centers them on the round screen.
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                // From res/values/strings.xml, so the text is translated like the rest of the UI.
                text = stringResource(R.string.app_name),
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.title1,
            )
        }
    }
}

// Shown in the Android Studio design pane on a round watch, without running the emulator.
@Preview(device = Devices.WEAR_OS_SMALL_ROUND, showSystemUi = true)
@Composable
fun ElderGuardAppPreview() {
    ElderGuardApp()
}
