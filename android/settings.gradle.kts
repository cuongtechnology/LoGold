pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // Nâng từ 2.1.0 → 2.3.0: google_mobile_ads (play-services-ads 25.3.0)
    // được biên dịch với metadata Kotlin 2.3.0, compiler cũ hơn không đọc được.
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    // Chỉ thực sự apply trong app/build.gradle.kts nếu google-services.json
    // tồn tại — tránh vỡ build cho ai chưa cấu hình Firebase.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
