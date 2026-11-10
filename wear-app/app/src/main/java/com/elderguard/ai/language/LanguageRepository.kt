package com.elderguard.ai.language

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The language chosen by the user, saved across restarts. Starts in Spanish unless English was
 * saved; the language of the watch is never used. Storage failures never crash the app: a failed
 * read falls back to Spanish, and a failed write still changes the language until the app closes.
 */
class LanguageRepository(private val storage: LanguageStorage) {
    private val _language = MutableStateFlow(readSaved())

    /** The current language. The UI collects it, so text changes as soon as the language does. */
    val language: StateFlow<AppLanguage> = _language.asStateFlow()

    fun setLanguage(language: AppLanguage) {
        _language.value = language
        try {
            storage.write(language.tag)
        } catch (_: Exception) {
            // Not saved: the change still applies for this session.
        }
    }

    private fun readSaved(): AppLanguage {
        val tag = try {
            storage.read()
        } catch (_: Exception) {
            null
        }
        return AppLanguage.fromTag(tag) ?: AppLanguage.Default
    }
}
