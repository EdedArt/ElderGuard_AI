package com.elderguard.ai.ui

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.wear.compose.material.MaterialTheme
import com.elderguard.ai.config.SosConfig
import com.elderguard.ai.language.AppLanguage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

private const val HOLD = SosConfig.HOLD_DURATION_MS.toLong()

// A margin of a few frames: the hold starts on the first frame after the touch.
private const val MARGIN = 100L

/**
 * The SOS hold, on the JVM through Robolectric. With autoAdvance off, time only moves when the
 * test calls mainClock.advanceTimeBy, like vi.advanceTimersByTime with Vitest's fake timers, so
 * a 2-second hold takes no real time.
 */
@RunWith(RobolectricTestRunner::class)
class SosButtonTest {
    @get:Rule
    val compose = createComposeRule()

    private var activations = 0

    private val button get() = compose.onNodeWithTag(SosButtonTags.BUTTON)

    @Before
    fun setUp() {
        compose.setContent {
            ProvideAppLanguage(AppLanguage.Es) {
                MaterialTheme { SosButton(onActivate = { activations++ }) }
            }
        }
        compose.mainClock.autoAdvance = false
    }

    private fun holdFor(millis: Long) {
        button.performTouchInput { down(center) }
        compose.mainClock.advanceTimeBy(millis)
    }

    private fun release() {
        button.performTouchInput { up() }
        compose.mainClock.advanceTimeBy(MARGIN)
    }

    private fun progress(): Float =
        compose.onNodeWithTag(SosButtonTags.PROGRESS)
            .fetchSemanticsNode()
            .config[SemanticsProperties.ProgressBarRangeInfo]
            .current

    @Test
    fun activatesAfterAFullHoldWithoutWaitingForRelease() {
        holdFor(HOLD + MARGIN)

        assertEquals(1, activations)

        release()
        assertEquals(1, activations)
        compose.onNodeWithTag(SosButtonTags.HINT).assertDoesNotExist()
    }

    @Test
    fun doesNotActivateBeforeTheHoldIsComplete() {
        holdFor(HOLD - MARGIN)

        assertEquals(0, activations)
    }

    @Test
    fun fillsTheProgressRingWhileHeld() {
        compose.onNodeWithTag(SosButtonTags.PROGRESS).assertDoesNotExist()

        holdFor(HOLD / 2)

        assertTrue("progress was ${progress()}", progress() in 0.4f..0.6f)
    }

    @Test
    fun earlyReleaseCancelsAndShowsTheHint() {
        holdFor(HOLD / 2)
        release()

        compose.onNodeWithTag(SosButtonTags.PROGRESS).assertDoesNotExist()
        compose.onNodeWithText("Mantén presionado").assertIsDisplayed()
        // The hold would have finished by now if it were still running.
        compose.mainClock.advanceTimeBy(HOLD)
        assertEquals(0, activations)
    }

    @Test
    fun hidesTheHintAfterTwoSeconds() {
        holdFor(MARGIN)
        release()
        compose.onNodeWithTag(SosButtonTags.HINT).assertIsDisplayed()

        compose.mainClock.advanceTimeBy(SosConfig.HOLD_HINT_DURATION_MS + MARGIN)

        compose.onNodeWithTag(SosButtonTags.HINT).assertDoesNotExist()
    }

    @Test
    fun aNewHoldHidesTheHintAndStartsFromZero() {
        holdFor(HOLD / 2)
        release()

        holdFor(MARGIN)

        compose.onNodeWithTag(SosButtonTags.HINT).assertDoesNotExist()
        assertTrue("progress was ${progress()}", progress() < 0.2f)
        compose.mainClock.advanceTimeBy(HOLD)
        assertEquals(1, activations)
    }
}
