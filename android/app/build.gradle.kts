import java.util.Base64
import java.net.URI

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.myapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.myapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 11 uses Android Keystore APIs from API 23.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("demo") {
            dimension = "environment"
            applicationIdSuffix = ".demo"
            resValue("string", "app_name", "TBScreen DEMO")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "TBScreen STAGING")
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "TBScreen")
        }
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Remove production variants entirely until the clinical gate is approved.
// Packaging/install tasks cannot bypass a disabled variant.
androidComponents {
    beforeVariants(selector().withFlavor("environment" to "production")) { variant ->
        variant.enable = false
    }
}

val buildDefines = (project.findProperty("dart-defines") as? String ?: "")
    .split(",").filter { it.isNotBlank() }.associate {
        val decoded = String(Base64.getDecoder().decode(it))
        decoded.substringBefore("=") to decoded.substringAfter("=", "")
    }
val appEnvironment = buildDefines["APP_ENV"] ?: "demo"
check(appEnvironment in listOf("demo", "staging")) { "Clinical gate incomplete: production locked" }
check(gradle.startParameter.taskNames.none { it.contains("Production", ignoreCase = true) }) {
    "Clinical gate incomplete: production locked"
}
check(appEnvironment != "demo" || buildDefines["USE_HTTP"] != "true") {
    "Demo must use synthetic repositories; use staging for backend access"
}
if (appEnvironment == "staging") {
    val uri = URI(buildDefines["API_BASE_URL"] ?: "")
    check(uri.scheme == "https" && !uri.host.isNullOrBlank() &&
        uri.userInfo == null && uri.query == null && uri.fragment == null &&
        Regex("/api/v[1-9][0-9]*").matches(uri.path ?: "")) {
        "HTTPS versioned API_BASE_URL required"
    }
}
// Validate the resolved graph so indirect packaging/installation is covered.
gradle.taskGraph.whenReady {
    val artifactTasks = allTasks.filter {
        it.project == project &&
            Regex("^(assemble|bundle|package|install|compileFlutterBuild)(Demo|Staging).*", RegexOption.IGNORE_CASE)
                .matches(it.name)
    }
    check(artifactTasks.all { it.name.contains(appEnvironment, ignoreCase = true) }) {
        "Native artifact flavor must match APP_ENV"
    }
}
