package com.elderguard.ai.ui

import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTouchInput
import androidx.wear.compose.material.MaterialTheme
import com.elderguard.ai.alerts.AlertType
import com.elderguard.ai.alerts.SosReason
import com.elderguard.ai.config.FallDetectionConfig.COUNTDOWN_SECONDS
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_DURATION_MS
import com.elderguard.ai.config.SosConfig
import com.elderguard.ai.config.TelemetryConfig.TICK_INTERVAL_MS
import com.elderguard.ai.device.WatchDevice
import com.elderguard.ai.language.AppLanguage
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.Sensor
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

private const val SECOND = 1000L
private const val MARGIN = 100L
private const val SEED = 7

// The web app's mock contacts, one per line on the SOS screen.
private val CONTACT_LINES = listOf("Ana Ejemplo", "Luis Ejemplo", "Dra. Prueba").joinToString(separator = "\n")

// The values the web app's "Simulate fall" uses: an impact, then lying still.
private val SPIKE = Accelerometer(2.5, 1.8, 3.2)
private val STILL = Accelerometer(0.0, 0.0, 1.0)

/**
 * The fall flow on the whole watch screen, through Robolectric. The device runs in the
 * composition's scope and reads the time from the Compose test clock, so with autoAdvance off,
 * mainClock.advanceTimeBy moves the engine's ticks, the detection and the countdown together,
 * like vi.advanceTimersByTime in the web tests.
 */
@RunWith(RobolectricTestRunner::class)
class FallCountdownScreenTest {
    @get:Rule
    val compose = createComposeRule()

    private lateinit var device: WatchDevice

    private val mode get() = device.store.state.value.deviceStatus.mode

    private fun setApp(language: AppLanguage = AppLanguage.Es) {
        compose.setContent {
            val scope = rememberCoroutineScope()
            val watch = remember {
                WatchDevice(scope, now = { compose.mainClock.currentTime }, random = Random(SEED)).also {
                    device = it
                    it.start()
                }
            }
            val state by watch.store.state.collectAsState()
            val countdown by watch.countdown.remaining.collectAsState()
            val sosAlert by watch.alerts.sosAlert.collectAsState()
            ProvideAppLanguage(language) {
                MaterialTheme {
                    WatchApp(
                        state = state,
                        language = language,
                        onLanguageChange = {},
                        // As TelemetryViewModel does.
                        onSosActivate = { watch.sos.trigger(SosReason.Manual) },
                        onSosCancel = watch.sos::cancel,
                        fallCountdownSeconds = countdown,
                        onFallCancel = watch.fall::cancel,
                        sosAlert = sosAlert,
                    )
                }
            }
        }
        compose.mainClock.autoAdvance = false
    }

    private fun advance(millis: Long) = compose.mainClock.advanceTimeBy(millis)

    /** An impact held for one tick, then stillness, until the detector confirms the fall. */
    private fun simulateFall() {
        device.engine.setOverride(Sensor.ACCELEROMETER, SPIKE)
        advance(TICK_INTERVAL_MS)
        device.engine.setOverride(Sensor.ACCELEROMETER, STILL)
        advance(IMMOBILITY_DURATION_MS - SECOND)
        // Then a frame at a time, to catch the very moment the overlay appears.
        repeat(((SECOND * 3) / MARGIN).toInt()) {
            if (mode == DeviceMode.FallCountdown) return
            advance(MARGIN)
        }
        error("No fall detected")
    }

    private fun seconds() = compose.onNodeWithTag(FallCountdownTags.SECONDS)

    /**
     * The cancel button sits below the confirmation. On a small screen it may need scrolling into
     * view; when everything fits, the list cannot scroll at all, so it is only scrolled if needed.
     */
    private fun cancelSos() {
        if (compose.onAllNodesWithTag(SosScreenTags.CANCEL).fetchSemanticsNodes().isEmpty()) {
            compose.onNodeWithTag(SosScreenTags.LIST).performScrollToNode(hasTestTag(SosScreenTags.CANCEL))
        }
        compose.onNodeWithTag(SosScreenTags.CANCEL).performClick()
        advance(MARGIN)
    }

    private fun holdSos() {
        compose.onNodeWithTag(WatchfaceTags.LIST).performScrollToNode(hasTestTag(SosButtonTags.BUTTON))
        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { down(center) }
        advance(SosConfig.HOLD_DURATION_MS + MARGIN)
        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { up() }
        advance(MARGIN)
    }

    private fun ringProgress(): Float {
        val node: SemanticsNode = compose.onNodeWithTag(FallCountdownTags.RING).fetchSemanticsNode()
        return node.config[FallRingProgressKey]
    }

    @Test
    fun theOverlayAppearsWhenAFallIsDetected() {
        setApp()
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertDoesNotExist()

        simulateFall()
        advance(MARGIN)

        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertIsDisplayed()
        compose.onNodeWithText("¿Te caíste?").assertIsDisplayed()
        compose.onNodeWithText("ESTOY BIEN").assertIsDisplayed()
        seconds().assertTextEquals("$COUNTDOWN_SECONDS")
    }

    @Test
    fun stillnessWithoutAnImpactShowsNoOverlay() {
        setApp()
        device.engine.setOverride(Sensor.ACCELEROMETER, STILL)
        advance(IMMOBILITY_DURATION_MS * 3)

        assertEquals(DeviceMode.Monitoring, mode)
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertDoesNotExist()
    }

    @Test
    fun theNumberCountsDownOncePerSecondAndTheRingDrains() {
        setApp()
        simulateFall()
        advance(MARGIN)
        val fullRing = ringProgress()

        advance(SECOND)
        seconds().assertTextEquals("${COUNTDOWN_SECONDS - 1}")
        advance(SECOND)
        seconds().assertTextEquals("${COUNTDOWN_SECONDS - 2}")
        advance(SECOND * 5)
        seconds().assertTextEquals("${COUNTDOWN_SECONDS - 7}")

        val laterRing = ringProgress()
        assertTrue("The ring drains: $fullRing then $laterRing", laterRing < fullRing)
        assertTrue("About a third is left: $laterRing", laterRing in 0.15f..0.35f)
    }

    @Test
    fun imOkCancelsTheCountdownAndRestoresMonitoring() {
        setApp()
        simulateFall()
        advance(SECOND * 3)

        compose.onNodeWithTag(FallCountdownTags.CANCEL).performClick()
        advance(MARGIN)

        assertEquals(DeviceMode.Monitoring, mode)
        assertFalse(device.countdown.isRunning)
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertDoesNotExist()

        // Long past the countdown: no SOS follows a cancelled fall.
        advance(COUNTDOWN_SECONDS * SECOND)
        assertEquals(DeviceMode.Monitoring, mode)
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertDoesNotExist()
    }

    @Test
    fun monitoringResumesAfterCancellingSoANewFallIsDetected() {
        setApp()
        simulateFall()
        compose.onNodeWithTag(FallCountdownTags.CANCEL).performClick()
        advance(MARGIN)

        simulateFall()
        advance(MARGIN)

        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertIsDisplayed()
        seconds().assertTextEquals("$COUNTDOWN_SECONDS")
    }

    @Test
    fun reachingZeroProceedsToSos() {
        setApp()
        simulateFall()

        // Half a second before zero: simulateFall returns up to one step after the start.
        advance(COUNTDOWN_SECONDS * SECOND - SECOND / 2)
        assertEquals(DeviceMode.FallCountdown, mode)
        seconds().assertTextEquals("1")

        advance(SECOND)
        assertEquals(DeviceMode.Sos, mode)
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertDoesNotExist()
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertIsDisplayed()
        compose.onNodeWithText("Pidiendo ayuda…").assertIsDisplayed()
        assertEquals(SosReason.Fall, device.sos.active.value?.reason)
    }

    @Test
    fun aLongPressOnSosKeepsTheManualReason() {
        setApp()
        holdSos()

        assertEquals(DeviceMode.Sos, mode)
        assertEquals(SosReason.Manual, device.sos.active.value?.reason)
    }

    @Test
    fun cancellingTheFallSosRestoresMonitoringAndDetection() {
        setApp()
        simulateFall()
        advance(COUNTDOWN_SECONDS * SECOND + MARGIN)
        assertEquals(DeviceMode.Sos, mode)

        cancelSos()
        assertEquals(DeviceMode.Monitoring, mode)
        assertEquals(null, device.sos.active.value)

        simulateFall()
        advance(MARGIN)
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertIsDisplayed()
    }

    @Test
    fun theOverlayBlocksTheWatchfaceBehindIt() {
        setApp()
        simulateFall()
        advance(MARGIN)

        // A tap away from the button does not reach the watchface, nor dismiss the overlay.
        compose.onNodeWithTag(WatchfaceTags.BATTERY).performClick()
        advance(MARGIN)

        assertEquals(DeviceMode.FallCountdown, mode)
        compose.onNodeWithTag(FallCountdownTags.SCREEN).assertIsDisplayed()
    }

    @Test
    fun speaksEnglishWhenChosen() {
        setApp(AppLanguage.En)
        simulateFall()
        advance(MARGIN)

        compose.onNodeWithText("Did you fall?").assertIsDisplayed()
        compose.onNodeWithText("I'M OK").assertIsDisplayed()
    }

    // --- Alert confirmation on the SOS screen ---

    @Test
    fun aFallSosShowsTheNotifiedContactsAndTheGpsCoordinates() {
        setApp()
        simulateFall()
        advance(COUNTDOWN_SECONDS * SECOND + MARGIN)

        val alert = device.alerts.sosAlert.value!!
        assertEquals(AlertType.Fall, alert.type)
        compose.onNodeWithTag(SosScreenTags.CONFIRMATION).assertIsDisplayed()
        compose.onNodeWithText("Avisados (simulado)").assertIsDisplayed()
        compose.onNodeWithTag(SosScreenTags.CONTACTS).assertTextEquals(CONTACT_LINES)
        compose.onNodeWithTag(SosScreenTags.LOCATION)
            .assertTextEquals("GPS: ${formatCoordinate(alert.gps.lat)}, ${formatCoordinate(alert.gps.lng)}")
    }

    @Test
    fun aManualSosShowsTheSameConfirmation() {
        setApp()
        holdSos()

        assertEquals(AlertType.ManualSos, device.alerts.sosAlert.value?.type)
        compose.onNodeWithTag(SosScreenTags.CONTACTS).assertTextEquals(CONTACT_LINES)
    }

    @Test
    fun withoutSignalTheConfirmationGivesTheLastPosition() {
        setApp()
        device.engine.setPartialOverride(Sensor.GPS) { it.copy(lat = 4.6, lng = -74.08, signal = false) }
        holdSos()

        compose.onNodeWithTag(SosScreenTags.LOCATION).assertTextEquals("Última posición: 4.60000, -74.08000")
    }

    @Test
    fun theConfirmationFollowsTheLanguage() {
        setApp(AppLanguage.En)
        device.engine.setPartialOverride(Sensor.GPS) { it.copy(lat = 4.6, lng = -74.08, signal = false) }
        holdSos()

        compose.onNodeWithText("Notified (mock)").assertIsDisplayed()
        compose.onNodeWithTag(SosScreenTags.LOCATION).assertTextEquals("Last position: 4.60000, -74.08000")
    }

    @Test
    fun theNextSosDoesNotShowThePreviousConfirmation() {
        setApp()
        holdSos()
        val first = device.alerts.sosAlert.value
        cancelSos()
        assertEquals(null, device.alerts.sosAlert.value)
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertDoesNotExist()

        advance(SECOND * 3)
        holdSos()
        val second = device.alerts.sosAlert.value!!
        assertTrue(second.timestamp > first!!.timestamp)
        assertEquals(2, device.alerts.alerts.value.size)
    }
}
