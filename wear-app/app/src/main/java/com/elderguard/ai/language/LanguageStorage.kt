package com.elderguard.ai.language

import android.content.Context

/**
 * Where the chosen language is saved. An interface so tests can replace the real storage,
 * including one that fails, without an Android device.
 */
interface LanguageStorage {
    /** The saved language tag, or null if none was saved. May throw if storage is unavailable. */
    fun read(): String?

    /** Saves the language tag. May throw if storage is unavailable. */
    fun write(tag: String)
}

/** Saves the language in SharedPreferences, a small key-value file private to the app. */
class SharedPreferencesLanguageStorage(private val context: Context) : LanguageStorage {
    // Opened on each call rather than in the constructor, so a failure surfaces in read() or
    // write(), where LanguageRepository handles it.
    private val preferences
        get() = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun read(): String? = preferences.getString(KEY_LANGUAGE, null)

    override fun write(tag: String) {
        // apply() writes to disk in the background, without blocking the UI thread.
        preferences.edit().putString(KEY_LANGUAGE, tag).apply()
    }

    private companion object {
        const val PREFERENCES_NAME = "settings"
        const val KEY_LANGUAGE = "language"
    }
}
