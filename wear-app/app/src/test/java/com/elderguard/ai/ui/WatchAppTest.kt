package com.elderguard.ai.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeRight
import androidx.wear.compose.material.MaterialTheme
import com.elderguard.ai.config.SosConfig
import com.elderguard.ai.language.AppLanguage
import com.elderguard.ai.language.LanguageRepository
import com.elderguard.ai.language.LanguageStorage
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.HealthAlert
import com.elderguard.ai.telemetry.TelemetryStore
import java.time.Clock
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

private const val HOLD = SosConfig.HOLD_DURATION_MS.toLong()
private const val MARGIN = 100L

/** A clock the test moves by hand. Sunday 8 November 2026, 9:05 p.m. UTC by default. */
private class MutableClock(var now: Instant = Instant.parse("2026-11-08T21:05:00Z")) : Clock() {
    override fun getZone(): ZoneId = ZoneOffset.UTC

    override fun withZone(zone: ZoneId): Clock = this

    override fun instant(): Instant = now
}

private class InMemoryStorage : LanguageStorage {
    var saved: String? = null

    override fun read(): String? = saved

    override fun write(tag: String) {
        saved = tag
    }
}

private fun hasStatusColor(color: Color) = SemanticsMatcher.expectValue(StatusColorKey, color)

/**
 * The whole watch screen on the JVM through Robolectric, wired to a real TelemetryStore and
 * LanguageRepository, as MainActivity does, but without the simulation engine so values stay put.
 */
@RunWith(RobolectricTestRunner::class)
class WatchAppTest {
    @get:Rule
    val compose = createComposeRule()

    private val store = TelemetryStore()
    private val storage = InMemoryStorage()
    private val languages = LanguageRepository(storage)
    private val clock = MutableClock()
    private var criticalHeartRate by mutableStateOf(false)

    private fun setApp() {
        compose.setContent {
            val state by store.state.collectAsState()
            val language by languages.language.collectAsState()
            CompositionLocalProvider(LocalClock provides clock) {
                ProvideAppLanguage(language) {
                    MaterialTheme {
                        WatchApp(
                            state = state,
                            language = language,
                            onLanguageChange = languages::setLanguage,
                            onSosActivate = { store.setMode(DeviceMode.Sos) },
                            onSosCancel = { store.setMode(DeviceMode.Monitoring) },
                            criticalHeartRate = criticalHeartRate,
                        )
                    }
                }
            }
        }
    }

    private fun scrollToSos() {
        compose.onNodeWithTag(WatchfaceTags.LIST).performScrollToNode(hasTestTag(SosButtonTags.BUTTON))
    }

    // --- Clock ---

    @Test
    fun rendersTheTwelveHourClockAndDateInSpanish() {
        setApp()

        compose.onNodeWithTag(WatchfaceTags.CLOCK)
            .assertIsDisplayed()
            .assert(hasText("9:05"))
            .assert(hasText("p. m."))
            .assert(hasText("dom, 8 nov"))
    }

    @Test
    fun updatesTheClockAsTimePasses() {
        setApp()
        compose.mainClock.autoAdvance = false

        clock.now = clock.now.plusSeconds(60)
        compose.mainClock.advanceTimeBy(1000 + MARGIN)

        compose.onNodeWithTag(WatchfaceTags.CLOCK).assert(hasText("9:06"))
    }

    // --- Status colors ---

    @Test
    fun colorsTheBatteryByLevel() {
        setApp()
        val battery = compose.onNodeWithTag(WatchfaceTags.BATTERY)
        battery.assert(hasStatusColor(WatchColors.Success)).assert(hasText("100 %"))

        store.update { it.copy(battery = it.battery.copy(level = 15.0)) }
        battery.assert(hasStatusColor(WatchColors.Warning)).assert(hasText("15 %"))

        store.update { it.copy(battery = it.battery.copy(level = 5.0)) }
        battery.assert(hasStatusColor(WatchColors.DangerText)).assert(hasText("5 %"))
    }

    @Test
    fun colorsAndLabelsTheGpsBySignal() {
        setApp()
        val gps = compose.onNodeWithTag(WatchfaceTags.GPS)
        gps.assert(hasStatusColor(WatchColors.Success)).assert(hasText("GPS"))

        store.update { it.copy(gps = it.gps.copy(signal = false)) }

        gps.assert(hasStatusColor(WatchColors.Warning)).assert(hasText("Sin GPS"))
    }

    // --- Heart rate banner ---

    private fun setHealthAlert(healthAlert: HealthAlert?) {
        store.update { it.copy(deviceStatus = it.deviceStatus.copy(healthAlert = healthAlert)) }
    }

    @Test
    fun showsTheHeartRateBannerOnlyWhileTheWarningLasts() {
        setApp()
        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER).assertDoesNotExist()

        setHealthAlert(HealthAlert.HighHeartRate)
        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER)
            .assertIsDisplayed()
            .assert(hasText("Ritmo cardíaco alto en reposo"))
            .assert(hasStatusColor(WatchColors.Warning))
        // A warning, not an alert: the watchface stays usable.
        compose.onNodeWithTag(WatchfaceTags.CLOCK).assertIsDisplayed()

        setHealthAlert(null)
        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER).assertDoesNotExist()
    }

    @Test
    fun theHeartRateBannerFollowsTheLanguage() {
        languages.setLanguage(AppLanguage.En)
        setHealthAlert(HealthAlert.HighHeartRate)
        setApp()

        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER).assert(hasText("High heart rate at rest"))
    }

    @Test
    fun aCriticalHeartRateTurnsTheBannerRedAndSaysTheFamilyWasTold() {
        setApp()
        setHealthAlert(HealthAlert.HighHeartRate)
        criticalHeartRate = true

        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER)
            .assert(hasText("Ritmo crítico: familia avisada"))
            .assert(hasStatusColor(WatchColors.Danger))

        criticalHeartRate = false
        compose.onNodeWithTag(WatchfaceTags.HEART_RATE_BANNER)
            .assert(hasText("Ritmo cardíaco alto en reposo"))
            .assert(hasStatusColor(WatchColors.Warning))
    }

    // --- SOS ---

    @Test
    fun activatesSosAfterATwoSecondHoldAndCancelsFromTheSosScreen() {
        setApp()
        scrollToSos()
        compose.mainClock.autoAdvance = false

        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(HOLD - MARGIN)
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertDoesNotExist()

        compose.mainClock.advanceTimeBy(MARGIN * 2)
        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { up() }
        compose.mainClock.advanceTimeBy(MARGIN)

        assertEquals(DeviceMode.Sos, store.state.value.deviceStatus.mode)
        compose.onNodeWithText("Pidiendo ayuda…").assertIsDisplayed()

        compose.onNodeWithTag(SosScreenTags.CANCEL).performClick()
        compose.mainClock.advanceTimeBy(MARGIN)

        assertEquals(DeviceMode.Monitoring, store.state.value.deviceStatus.mode)
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertDoesNotExist()
    }

    @Test
    fun earlyReleaseCancelsSosAndShowsTheHint() {
        setApp()
        scrollToSos()
        compose.mainClock.autoAdvance = false

        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(HOLD / 2)
        compose.onNodeWithTag(SosButtonTags.BUTTON).performTouchInput { up() }
        compose.mainClock.advanceTimeBy(MARGIN)

        compose.onNodeWithText("Mantén presionado").assertIsDisplayed()
        compose.mainClock.advanceTimeBy(HOLD)
        assertEquals(DeviceMode.Monitoring, store.state.value.deviceStatus.mode)
        compose.onNodeWithTag(SosScreenTags.SCREEN).assertDoesNotExist()
    }

    @Test
    fun hidesTheHoldHintAfterTwoSecondsOrWhenANewHoldStarts() {
        setApp()
        scrollToSos()
        compose.mainClock.autoAdvance = false
        val button = compose.onNodeWithTag(SosButtonTags.BUTTON)

        button.performTouchInput { down(center) }
        button.performTouchInput { up() }
        compose.mainClock.advanceTimeBy(MARGIN)
        compose.onNodeWithTag(HOLD_HINT_TAG).assertIsDisplayed()

        button.performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(MARGIN)
        compose.onNodeWithTag(HOLD_HINT_TAG).assertDoesNotExist()

        button.performTouchInput { up() }
        compose.mainClock.advanceTimeBy(MARGIN)
        compose.onNodeWithTag(HOLD_HINT_TAG).assertIsDisplayed()
        compose.mainClock.advanceTimeBy(SosConfig.HOLD_HINT_DURATION_MS + MARGIN)
        compose.onNodeWithTag(HOLD_HINT_TAG).assertDoesNotExist()
    }

    @Test
    fun theSosScreenBlocksTheWatchfaceBehindIt() {
        store.setMode(DeviceMode.Sos)
        setApp()

        compose.onNodeWithTag(SosScreenTags.SCREEN).assertIsDisplayed()
        // Neither a tap on the battery (away from Cancel) nor a swipe to the language page gets
        // through to the watchface; the screen stays until Cancel.
        compose.onNodeWithTag(WatchfaceTags.BATTERY).performClick()
        compose.onNodeWithTag(WatchAppTags.PAGER).performTouchInput { swipeLeft() }

        compose.onNodeWithTag(SosScreenTags.SCREEN).assertIsDisplayed()
        compose.onNodeWithTag(LanguageScreenTags.SCREEN).assertDoesNotExist()
        assertEquals(DeviceMode.Sos, store.state.value.deviceStatus.mode)
    }

    // --- Language ---

    @Test
    fun theLanguageScreenSwitchesTheWholeWatchToEnglishAndSavesIt() {
        setApp()

        compose.onNodeWithTag(WatchAppTags.PAGER).performTouchInput { swipeLeft() }
        compose.onNodeWithText("Idioma").assertIsDisplayed()
        compose.onNodeWithTag(LanguageScreenTags.option(AppLanguage.Es)).assertIsSelected()

        compose.onNodeWithTag(LanguageScreenTags.option(AppLanguage.En)).performClick()

        compose.onNodeWithText("Language").assertIsDisplayed()
        compose.onNodeWithTag(LanguageScreenTags.option(AppLanguage.En)).assertIsSelected()
        compose.onNodeWithTag(LanguageScreenTags.option(AppLanguage.Es)).assertIsNotSelected()
        assertEquals("en", storage.saved)

        compose.onNodeWithTag(WatchAppTags.PAGER).performTouchInput { swipeRight() }
        compose.onNodeWithTag(WatchfaceTags.CLOCK).assert(hasText("PM")).assert(hasText("Sun, Nov 8"))
        compose.onNodeWithTag(WatchfaceTags.BATTERY).assert(hasText("100%"))
    }
}
