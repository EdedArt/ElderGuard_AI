package com.elderguard.ai.language

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Keeps the saved tag in memory, like SharedPreferences across app restarts. */
private class InMemoryStorage(var saved: String? = null) : LanguageStorage {
    override fun read(): String? = saved

    override fun write(tag: String) {
        saved = tag
    }
}

/** Storage that is never available, for example a corrupted preferences file. */
private class BrokenStorage : LanguageStorage {
    override fun read(): String? = throw IllegalStateException("Storage unavailable")

    override fun write(tag: String) = throw IllegalStateException("Storage unavailable")
}

class LanguageRepositoryTest {
    @Test
    fun defaultsToSpanish() {
        assertEquals(AppLanguage.Es, LanguageRepository(InMemoryStorage()).language.value)
    }

    @Test
    fun persistsAChangeAcrossRestarts() {
        val storage = InMemoryStorage()
        LanguageRepository(storage).setLanguage(AppLanguage.En)

        val restarted = LanguageRepository(storage)

        assertEquals("en", storage.saved)
        assertEquals(AppLanguage.En, restarted.language.value)
    }

    @Test
    fun updatesTheStateFlowRightAway() {
        val repository = LanguageRepository(InMemoryStorage())

        repository.setLanguage(AppLanguage.En)
        assertEquals(AppLanguage.En, repository.language.value)

        repository.setLanguage(AppLanguage.Es)
        assertEquals(AppLanguage.Es, repository.language.value)
    }

    @Test
    fun fallsBackToSpanishWhenStorageIsUnavailable() {
        assertEquals(AppLanguage.Es, LanguageRepository(BrokenStorage()).language.value)
    }

    @Test
    fun stillChangesTheLanguageWhenSavingFails() {
        val repository = LanguageRepository(BrokenStorage())

        repository.setLanguage(AppLanguage.En)

        assertEquals(AppLanguage.En, repository.language.value)
    }

    @Test
    fun fallsBackToSpanishForAnUnknownSavedValue() {
        assertEquals(AppLanguage.Es, LanguageRepository(InMemoryStorage("fr")).language.value)
    }

    @Test
    fun mapsTagsToLanguages() {
        assertEquals(AppLanguage.Es, AppLanguage.fromTag("es"))
        assertEquals(AppLanguage.En, AppLanguage.fromTag("en"))
        assertNull(AppLanguage.fromTag(null))
    }
}
