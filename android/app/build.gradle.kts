plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zeepowertoys.zee_power_toys"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zeepowertoys.zee_power_toys"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        // androidx.car.app host-side AIDL types are @RestrictTo(LIBRARY) but compile
        // cleanly — the restriction is advisory (internal AAR API), not an error.
        // Phase0 uses the same suppression to build with androidx.car.app:app:1.4.0.
        disable += "RestrictedApi"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // AndroidX Car App library — provides ICarApp, IAppHost, ISurfaceCallback, SurfaceContainer,
    // HandshakeInfo, SessionInfo, CarAppApiLevels, and all AIDL types used by YNaviCarAppHost.
    // Host-side types are @RestrictTo(LIBRARY) but publicly available in the AAR.
    implementation("androidx.car.app:app:1.4.0")
}
