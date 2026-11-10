package com.elderguard.ai.language

import java.util.Locale

/** The languages of the app. Spanish is the default, whatever the language of the watch. */
enum class AppLanguage(val tag: String) {
    Es("es"),
    En("en"),
    ;

    val locale: Locale
        get() = Locale.forLanguageTag(tag)

    companion object {
        val Default = Es

        /** The language with this tag, or null for an unknown or missing tag. */
        fun fromTag(tag: String?): AppLanguage? = entries.firstOrNull { it.tag == tag }
    }
}
