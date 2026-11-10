package com.elderguard.ai.ui

import android.content.ContextWrapper
import android.content.res.Configuration
import android.content.res.Resources
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import com.elderguard.ai.language.AppLanguage

/** The app language, for code that formats text itself (such as dates) instead of using resources. */
val LocalAppLanguage = staticCompositionLocalOf { AppLanguage.Default }

/**
 * Makes [content] use the strings of [language] instead of the watch's language.
 *
 * stringResource() reads LocalContext and LocalConfiguration, so providing localized versions of
 * both is enough: when the language changes, every text below recomposes in the new language
 * at once, without restarting the activity.
 */
@Composable
fun ProvideAppLanguage(language: AppLanguage, content: @Composable () -> Unit) {
    val baseContext = LocalContext.current
    val baseConfiguration = LocalConfiguration.current
    val configuration = remember(baseConfiguration, language) {
        Configuration(baseConfiguration).apply { setLocale(language.locale) }
    }
    val context = remember(baseContext, configuration) {
        val localizedResources = baseContext.createConfigurationContext(configuration).resources
        // Wraps the original context instead of replacing it, so code that looks for the
        // activity behind LocalContext still finds it.
        object : ContextWrapper(baseContext) {
            override fun getResources(): Resources = localizedResources
        }
    }
    CompositionLocalProvider(
        LocalContext provides context,
        LocalConfiguration provides configuration,
        LocalAppLanguage provides language,
        content = content,
    )
}
