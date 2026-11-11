package com.elderguard.ai.alerts

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors tests/countdown.test.js. runTest's virtual time replaces the hand-driven timer:
 * advanceTimeBy moves it instantly, like vi.advanceTimersByTime.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class CountdownTest {
    private var completed = 0

    private fun TestScope.countdown(): Pair<Countdown, List<Int?>> {
        val countdown = Countdown(backgroundScope)
        val seen = mutableListOf<Int?>()
        // Unconfined: records every value, none skipped.
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { countdown.remaining.collect { seen += it } }
        return countdown to seen
    }

    // advanceTimeBy runs what is due strictly before the target; runCurrent runs what is due at it.
    private fun TestScope.advance(millis: Long) {
        advanceTimeBy(millis)
        runCurrent()
    }

    @Test
    fun isNotRunningUntilStarted() = runTest {
        val (countdown, seen) = countdown()
        assertFalse(countdown.isRunning)
        assertEquals(listOf(null), seen)
    }

    @Test
    fun reportsTheStartingValueRightAway() = runTest {
        val (countdown, seen) = countdown()
        countdown.start(3) { completed++ }
        assertEquals(listOf(null, 3), seen)
        assertTrue(countdown.isRunning)
    }

    @Test
    fun countsDownOncePerSecondToZeroAndThenCompletesOnce() = runTest {
        val (countdown, seen) = countdown()
        countdown.start(3) { completed++ }

        advance(999)
        assertEquals(listOf(null, 3), seen)
        advance(1)
        assertEquals(listOf(null, 3, 2), seen)
        advance(1000)
        assertEquals(0, completed)

        advance(1000)
        assertEquals(listOf(null, 3, 2, 1, 0, null), seen)
        assertEquals(1, completed)
        assertFalse(countdown.isRunning)
    }

    @Test
    fun ignoresASecondStartWhileRunning() = runTest {
        val (countdown, seen) = countdown()
        countdown.start(3) { completed++ }
        advance(1000)
        countdown.start(10) { completed += 100 }

        advance(5000)
        assertEquals(listOf(null, 3, 2, 1, 0, null), seen)
        assertEquals(1, completed)
    }

    @Test
    fun canStartAgainAfterCompleting() = runTest {
        val (countdown, _) = countdown()
        countdown.start(1) { completed++ }
        advance(1000)
        countdown.start(1) { completed++ }
        advance(1000)
        assertEquals(2, completed)
    }

    @Test
    fun completesRightAwayFromZero() = runTest {
        val (countdown, _) = countdown()
        countdown.start(0) { completed++ }
        runCurrent()
        assertEquals(1, completed)
        assertFalse(countdown.isRunning)
    }

    @Test
    fun cancelStopsTheTicksAndNeverCompletes() = runTest {
        val (countdown, seen) = countdown()
        countdown.start(3) { completed++ }
        advance(1000)
        countdown.cancel()
        advance(5000)

        assertEquals(listOf(null, 3, 2, null), seen)
        assertEquals(0, completed)
        assertFalse(countdown.isRunning)
    }

    @Test
    fun cancelDoesNothingWhenNotRunning() = runTest {
        val (countdown, _) = countdown()
        countdown.cancel()
        assertFalse(countdown.isRunning)
    }

    @Test
    fun cancelAllowsANewStartFromTheFullValue() = runTest {
        val (countdown, seen) = countdown()
        countdown.start(3) { completed++ }
        advance(1000)
        countdown.cancel()

        countdown.start(3) { completed++ }
        assertEquals(listOf(null, 3, 2, null, 3), seen)
    }

    @Test
    fun cancellingOnTheLastSecondPreventsCompletion() = runTest {
        val (countdown, _) = countdown()
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            countdown.remaining.collect { if (it == 0) countdown.cancel() }
        }
        countdown.start(1) { completed++ }
        advance(1000)
        assertEquals(0, completed)
    }
}
