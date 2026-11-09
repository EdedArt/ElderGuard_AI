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

    debugImplementation(libs.androidx.compose.ui.tooling)
}
