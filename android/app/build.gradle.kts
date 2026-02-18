import java.util.Properties
import java.io.FileInputStream

val autofillMvpEnabled = (project.findProperty("oneruleAutofillMvpEnabled") as String?)
    ?.toBooleanStrictOrNull() ?: false

// Keystore dosyasını yükleme işlemi
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin, Android ve Kotlin pluginlerinden sonra gelmelidir.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // DÜZELTME: Burası uygulamanızın paket yapısıyla aynı olmalıdır.
    // Eskiden "com.example.onerule" idi, bu yüzden hata alıyordunuz.
    namespace = "com.fidevelopment.onerule"
    
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        buildConfig = true
    
    }
    
    defaultConfig {
        // Application ID: Play Store'da görünen kimlik
        applicationId = "com.fidevelopment.onerule"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["oneRuleAutofillEnabled"] = autofillMvpEnabled.toString()
        buildConfigField(
            "boolean",
            "ONERULE_AUTOFILL_MVP",
            autofillMvpEnabled.toString()
        )
    }

    signingConfigs {
        create("release") {
            // key.properties dosyası varsa değerleri oradan al, yoksa boş geç (build hatasını önlemek için)
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Eğer key.properties düzgün yüklendiyse imzalama yapılandırmasını kullan
            if (keystoreProperties.isNotEmpty()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
