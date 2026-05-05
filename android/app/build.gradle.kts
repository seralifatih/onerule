import java.util.Properties
import java.io.FileInputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

val autofillMvpEnabled = (project.findProperty("oneruleAutofillMvpEnabled") as String?)
    ?.toBooleanStrictOrNull() ?: true

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
        isCoreLibraryDesugaringEnabled = true
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}

configurations.all {
    exclude(group = "com.google.android.play")
}

val stripPlayStoreFromFlutterEmbedding by tasks.registering {
    doLast {
        val gradleHome = gradle.gradleUserHomeDir
        val embeddingDir = file("${gradleHome}/caches/modules-2/files-2.1/io.flutter/flutter_embedding_release")
        if (!embeddingDir.exists()) {
            println("Flutter embedding cache not found at $embeddingDir, skipping strip")
            return@doLast
        }
        val jars = embeddingDir.walkTopDown()
            .filter { it.isFile && it.name.startsWith("flutter_embedding_release-") && it.name.endsWith(".jar") }
            .toList()
        jars.forEach { jar ->
            val tmp = file("${jar}.tmp")
            var stripped = 0
            ZipInputStream(jar.inputStream()).use { zin ->
                ZipOutputStream(tmp.outputStream()).use { zout ->
                    var entry = zin.nextEntry
                    while (entry != null) {
                        val drop = entry.name.startsWith("io/flutter/embedding/engine/deferredcomponents/PlayStoreDeferredComponentManager") ||
                                   entry.name == "io/flutter/embedding/android/FlutterPlayStoreSplitApplication.class"
                        if (!drop) {
                            zout.putNextEntry(ZipEntry(entry.name))
                            zin.copyTo(zout)
                            zout.closeEntry()
                        } else {
                            stripped++
                        }
                        entry = zin.nextEntry
                    }
                }
            }
            if (stripped > 0) {
                jar.delete()
                tmp.renameTo(jar)
                println("Stripped $stripped Play Store class(es) from $jar")
            } else {
                tmp.delete()
            }
        }
    }
}

afterEvaluate {
    tasks.matching { it.name == "preReleaseBuild" }.configureEach {
        dependsOn(stripPlayStoreFromFlutterEmbedding)
    }
}

flutter {
    source = "../.."
}
