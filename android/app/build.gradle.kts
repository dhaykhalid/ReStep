plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.restep.restep"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    packaging {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES", "META-INF/LICENSE*",
                "META-INF/NOTICE*", "META-INF/INDEX.LIST", "META-INF/ASL2.0"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.restep.restep"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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
    implementation("com.shimmerresearch:shimmerandroidinstrumentdriver:3.2.8_beta@aar")
    implementation("com.shimmerresearch:shimmerdriver:0.11.7_beta") {
        exclude(group = "io.netty")
        exclude(group = "com.google.protobuf")
        exclude(
            group = "com.google.api.grpc",
            module = "proto-google-common-protos"
        )
    }
    implementation("com.shimmerresearch:shimmerbluetoothmanager:0.11.7_beta") {
        exclude(group = "io.netty")
        exclude(group = "com.google.protobuf")
        exclude(group = "org.apache.commons.math")
        exclude(
            group = "com.google.api.grpc",
            module = "proto-google-common-protos"
        )
    }
    // مكتبات يحتاجها الـ driver (لأن @aar ما يجيب التوابع تلقائيًا)
    implementation("com.google.guava:guava:20.0")
    implementation("java3d:vecmath:1.3.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.github.Jasonchenlijian:FastBle:2.4.0")
}