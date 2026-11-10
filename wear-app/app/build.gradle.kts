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
}

dependencies {
    // The BOM picks matching versions for the androidx.compose libraries listed without one.
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
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

    // Local unit tests in src/test, run on the JVM with `gradlew.bat test` (no emulator needed).
    testImplementation(libs.junit)
    // Virtual time for coroutines, the equivalent of Vitest's fake timers.
    testImplementation(libs.kotlinx.coroutines.test)
}
