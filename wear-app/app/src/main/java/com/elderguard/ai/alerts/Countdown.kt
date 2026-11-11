package com.elderguard.ai.alerts

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

private const val TICK_MS = 1000L

/**
 * Port of src/core/countdown.js: counts down whole seconds in a coroutine launched in [scope].
 *
 * Instead of tick listeners, [remaining] reports the seconds left, from the starting value to 0,
 * and goes back to null when the countdown ends or is cancelled. A UI collecting it redraws on
 * every second. Since [scope]'s dispatcher runs the delays, tests control the time.
 */
class Countdown(private val scope: CoroutineScope) {
    private val _remaining = MutableStateFlow<Int?>(null)

    /** Seconds left while running, from the starting value down to 0; null when not running. */
    val remaining: StateFlow<Int?> = _remaining.asStateFlow()

    private var job: Job? = null

    val isRunning: Boolean
        get() = job?.isActive == true

    /**
     * Counts down from [seconds], then calls [onComplete]. Ignored while running, so a second
     * start can never restart or double the countdown.
     */
    fun start(seconds: Int, onComplete: () -> Unit) {
        if (isRunning) return
        _remaining.value = seconds
        job = scope.launch {
            var left = seconds
            while (left > 0) {
                delay(TICK_MS)
                left--
                _remaining.value = left
            }
            // Something that reacted to the last second may have cancelled the countdown, which
            // must then not complete.
            if (!isActive) return@launch
            _remaining.value = null
            onComplete()
        }
    }

    /** Stops the countdown without completing it. Does nothing when not running. */
    fun cancel() {
        job?.cancel()
        job = null
        _remaining.value = null
    }
}
