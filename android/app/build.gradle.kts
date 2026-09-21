plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Same AOSP/platform debug key phase0 uses on the Zeekr DHU (androiddebugkey).
// Enable with -PuseAospDebugKey=true or android/gradle.properties useAospDebugKey=true.
val useAospDebugKey = providers.gradleProperty("useAospDebugKey").orNull == "true"
val aospDebugKey = rootProject.file("tools/zeekr/androiddebugkey.jks")
val hasAospDebugKey = useAospDebugKey && aospDebugKey.exists()
val aospKeyAlias = providers.gradleProperty("aospKeyAlias").orNull ?: "androiddebugkey"
val aospStorePass = providers.gradleProperty("aospKeyStorePass").orNull ?: "android"
val aospKeyPass = providers.gradleProperty("aospKeyPass").orNull ?: aospStorePass

android {
    namespace = "com.zeepowertoys.zee_power_toys"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zeepowertoys.zee_power_toys"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasAospDebugKey) {
            create("aospDebug") {
                storeFile = aospDebugKey
                storePassword = aospStorePass
                keyAlias = aospKeyAlias
                keyPassword = aospKeyPass
            }
        }
    }

    buildTypes {
        debug {
            if (hasAospDebugKey) {
                signingConfig = signingConfigs.getByName("aospDebug")
            }
        }
        release {
            // 0054 keep-data: release/car APKs declare sharedUserId=android.uid.system.
            // They MUST sign with the AOSP/platform key so `adb install -r` keeps
            // SharedPreferences. Never silently fall back to Flutter debug.
            when {
                hasAospDebugKey -> {
                    signingConfig = signingConfigs.getByName("aospDebug")
                }
                useAospDebugKey -> {
                    // Keystore missing — leave unsigned here; afterEvaluate fails loudly
                    // on release package/assemble (do not wipe via adb uninstall).
                }
                else -> {
                    signingConfig = signingConfigs.getByName("debug")
                    logger.warn(
                        "0054: release signing with Flutter debug key " +
                            "(useAospDebugKey=false). Car `adb install -r` may hit " +
                            "SHARED_USER / UPDATE_INCOMPATIBLE.",
                    )
                }
            }
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

// 0054: release/car builds must fail loudly when platform key is required but missing.
// Do not configure-time throw (would break AVD debug on machines without the jks).
afterEvaluate {
    tasks.matching {
        val n = it.name
        n == "assembleRelease" ||
            n == "bundleRelease" ||
            n.startsWith("packageRelease") ||
            n.startsWith("signRelease")
    }.configureEach {
        doFirst {
            if (useAospDebugKey && !aospDebugKey.exists()) {
                throw GradleException(
                    "0054 keep-data: useAospDebugKey=true but missing " +
                        "${aospDebugKey.invariantSeparatorsPath}. " +
                        "Copy androiddebugkey.jks into android/tools/zeekr/ " +
                        "(see android/tools/zeekr/README.md). " +
                        "Release APKs keep sharedUserId=android.uid.system and must use " +
                        "the AOSP/platform key so `adb install -r` preserves prefs. " +
                        "NEVER `adb uninstall` to work around SHARED_USER_INCOMPATIBLE — that wipes settings.",
                )
            }
        }
    }
}
