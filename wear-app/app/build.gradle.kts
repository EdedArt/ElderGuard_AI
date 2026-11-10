import com.android.build.api.variant.HasUnitTestBuilder

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    // Compiles the @Composable functions. Since Kotlin 2.0 it ships with Kotlin itself.
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.elderguard.ai"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.elderguard.ai"
        // Wear OS 2 and later run API 26 or higher.
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        // Robolectric reads the app's real resources (strings, themes) in local UI tests.
        unitTests.isIncludeAndroidResources = true
    }
}

androidComponents {
    // Unit tests run on the debug variant only. The Compose test host activity comes from
    // ui-test-manifest, a debug-only dependency, and a release run would repeat the same tests.
    beforeVariants(selector().withBuildType("release")) { variant ->
        (variant as HasUnitTestBuilder).enableUnitTest = false
    }
}

dependencies {
    // The BOM picks matching versions for the androidx.compose libraries listed without one.
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    // Basic Material icons (heart, location, phone), versioned by the BOM.
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.activity.compose)
    // Wear OS versions of the Compose components, sized and styled for a round watch screen.
    implementation(libs.androidx.wear.compose.material)
    implementation(libs.androidx.wear.compose.foundation)
    // Coroutines and StateFlow, used by the telemetry engine.
    implementation(libs.kotlinx.coroutines.android)
    // ViewModel (keeps the engine alive across activity re-creation) and collectAsStateWithLifecycle.
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)

    debugImplementation(libs.androidx.compose.ui.tooling)
    // An empty activity that Compose UI tests draw into.
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // Local unit tests in src/test, run on the JVM with `gradlew.bat test` (no emulator needed).
    testImplementation(libs.junit)
    // Virtual time for coroutines, the equivalent of Vitest's fake timers.
    testImplementation(libs.kotlinx.coroutines.test)
    // Compose UI tests (with a controllable clock) running on the JVM through Robolectric,
    // which simulates Android so no emulator is needed.
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.robolectric)
}
