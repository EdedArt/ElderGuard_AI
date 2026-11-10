package com.elderguard.ai.ui

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.elderguard.ai.R
import com.elderguard.ai.language.AppLanguage

object LanguageScreenTags {
    const val SCREEN = "languageScreen"

    fun option(language: AppLanguage) = "language_${language.tag}"
}

private val OPTION_SHAPE = RoundedCornerShape(28.dp)

private val AppLanguage.code: Int
    @StringRes get() = when (this) {
        AppLanguage.Es -> R.string.language_es_code
        AppLanguage.En -> R.string.language_en_code
    }

private val AppLanguage.languageName: Int
    @StringRes get() = when (this) {
        AppLanguage.Es -> R.string.language_es_name
        AppLanguage.En -> R.string.language_en_name
    }

/**
 * Second page of the watch: one large button per language, the current one highlighted, like
 * the ES/EN buttons of the web app. The change applies at once and is saved.
 */
@Composable
fun LanguageScreen(
    current: AppLanguage,
    onSelect: (AppLanguage) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().testTag(LanguageScreenTags.SCREEN),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
    ) {
        Text(
            text = stringResource(R.string.language_title),
            style = MaterialTheme.typography.title2,
            modifier = Modifier.semantics { heading() },
        )
        // selectableGroup: screen readers present the buttons as one choice, "1 of 2".
        Column(
            modifier = Modifier.fillMaxWidth(0.8f).selectableGroup(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            for (language in AppLanguage.entries) {
                LanguageOption(language = language, selected = language == current, onSelect = { onSelect(language) })
            }
        }
    }
}

@Composable
private fun LanguageOption(language: AppLanguage, selected: Boolean, onSelect: () -> Unit) {
    val background = if (selected) WatchColors.Accent else Color.Transparent
    val content = if (selected) WatchColors.OnAccent else WatchColors.Text
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(OPTION_SHAPE)
            .background(background)
            .border(2.dp, if (selected) WatchColors.Accent else WatchColors.Text, OPTION_SHAPE)
            .selectable(selected = selected, onClick = onSelect, role = Role.RadioButton)
            .testTag(LanguageScreenTags.option(language)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = stringResource(language.code),
            color = content,
            style = MaterialTheme.typography.title2,
            fontWeight = FontWeight.Bold,
        )
        Text(text = stringResource(language.languageName), color = content, style = MaterialTheme.typography.caption1)
    }
}
