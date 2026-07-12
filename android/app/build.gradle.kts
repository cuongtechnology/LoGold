import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (push notification) cần `google-services.json` (tải từ Firebase
// Console → Project settings → app Android → đặt vào thư mục này). Apply có
// điều kiện để build vẫn chạy được khi chưa cấu hình Firebase.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Đọc `android/key.properties` (không commit; ignored).
// File này chứa: storeFile, storePassword, keyAlias, keyPassword.
// CI tạo file này on-the-fly từ secret trước khi build.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "vn.lo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications yêu cầu bật desugaring (dùng java.time API).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "vn.lo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Nếu key.properties tồn tại → dùng release keystore.
            // Nếu không → fallback debug (cho `flutter run --release` local).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 (rút gọn code + tài nguyên) — Play Console báo thiếu mục
            // này ở phần "Tối ưu hoá ứng dụng". BẮT BUỘC smoke-test bản APK
            // release trên thiết bị/emulator thật trước khi nộp Play Store:
            // R8 có thể âm thầm strip class dùng qua reflection (push
            // notification, AdMob) — lỗi này build vẫn thành công nhưng
            // crash lúc chạy thật, không phát hiện được lúc compile.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
