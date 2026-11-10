package com.elderguard.ai.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.PageIndicatorStyle
import com.elderguard.ai.language.AppLanguage
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryState

private const val WATCHFACE_PAGE = 0
private const val LANGUAGE_PAGE = 1
private const val PAGE_COUNT = 2

// Larger than the 6 dp default, so the dots are easier to notice.
private val INDICATOR_SIZE = 8.dp

object WatchAppTags {
    const val PAGER = "pager"
}

/**
 * Everything on the watch screen. Stateless: it draws [state] and reports actions through the
 * callbacks, so UI tests can drive it without the simulation engine.
 *
 * Two pages side by side: the watchface, and the language screen to its right (swipe left to
 * reach it). A right swipe on the watchface is left to Wear OS, which uses it to close apps.
 */
@Composable
fun WatchApp(
    state: TelemetryState,
    language: AppLanguage,
    onLanguageChange: (AppLanguage) -> Unit,
    onSosActivate: () -> Unit,
    onSosCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val pagerState = rememberPagerState(pageCount = { PAGE_COUNT })
    Box(modifier = modifier.fillMaxSize()) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize().testTag(WatchAppTags.PAGER)) { page ->
            when (page) {
                WATCHFACE_PAGE -> Watchface(state = state, onSosActivate = onSosActivate)
                LANGUAGE_PAGE -> LanguageScreen(current = language, onSelect = onLanguageChange)
            }
        }
        // The dots at the bottom that show there is a second page and which one is open.
        // Linear style: the default curved style drew nothing on the Wear OS emulator. A straight
        // row at the bottom center still sits inside the round screen.
        HorizontalPageIndicator(
            pageIndicatorState = rememberPageIndicatorState(pagerState),
            indicatorStyle = PageIndicatorStyle.Linear,
            indicatorSize = INDICATOR_SIZE,
        )
        if (state.deviceStatus.mode == DeviceMode.Sos) {
            SosScreen(onCancel = onSosCancel)
        }
    }
}

/** Adapts Compose's PagerState to the state Wear's page indicator reads. */
@Composable
private fun rememberPageIndicatorState(pagerState: PagerState): PageIndicatorState =
    remember(pagerState) {
        object : PageIndicatorState {
            override val pageOffset: Float
                get() = pagerState.currentPageOffsetFraction
            override val selectedPage: Int
                get() = pagerState.currentPage
            override val pageCount: Int
                get() = pagerState.pageCount
        }
    }
