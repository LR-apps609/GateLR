plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.compose")
    kotlin("plugin.serialization")
}

android {
    namespace = "app.gatelr"
    compileSdk = 35

    defaultConfig {
        applicationId = "app.gatelr"
        minSdk = 26                 // Android 8 e successivi: circa il 97% dei telefoni
        targetSdk = 35
        versionCode = 10
        versionName = "2.0.2"     // dalla 1.20.0 la stessa versione dell'app iPhone
    }

    // Firma per gli store: il file .jks e le password arrivano dai segreti di GitHub (vedi docs/android-store.md)
    val keystore = System.getenv("GATELR_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        if (keystore != null) create("store") {
            storeFile = keystore
            storePassword = System.getenv("GATELR_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("GATELR_KEY_ALIAS") ?: "gatelr"
            keyPassword = System.getenv("GATELR_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Senza chiave degli store si firma con quella di prova: così il giro sull'emulatore prova proprio la versione ottimizzata
            signingConfig = if (keystore != null) signingConfigs.getByName("store") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    sourceSets["main"].apply {
        // Il motore condiviso (stesso codice provato con i test in core/)
        java.srcDir("../core/src/main/kotlin")
        // Le città e le regole: gli stessi file dell'app iPhone, copiati negli assets alla compilazione
        assets.srcDir(layout.buildDirectory.dir("generated/gatelrAssets"))
        // 2.0: i caratteri dell'iPhone (Resources/Fonts): Titillium per i titoli, DotGothic16 per il pannello LED
        res.srcDir(layout.buildDirectory.dir("generated/gatelrRes"))
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}

val copyCityData by tasks.registering(Copy::class) {
    from(rootDir.resolve("../Resources")) {
        include("Cities/*.json", "Rules/*.json")
    }
    into(layout.buildDirectory.dir("generated/gatelrAssets"))
}
val copyFonts by tasks.registering(Copy::class) {
    from(rootDir.resolve("../Resources/Fonts")) {
        include("TitilliumWeb-SemiBold.ttf", "TitilliumWeb-Bold.ttf", "TitilliumWeb-Black.ttf", "DotGothic16-Regular.ttf")
        rename { n -> when (n) {
            "TitilliumWeb-SemiBold.ttf" -> "titillium_semibold.ttf"; "TitilliumWeb-Bold.ttf" -> "titillium_bold.ttf"
            "TitilliumWeb-Black.ttf" -> "titillium_black.ttf"; else -> "dotgothic16.ttf"
        } }
    }
    into(layout.buildDirectory.dir("generated/gatelrRes/font"))
}
tasks.named("preBuild") { dependsOn(copyCityData, copyFonts) }

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    // 2.0: widget piccolo e medio con Glance (Compose per i widget)
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    // Mappe senza servizi Google (vanno anche sui Huawei): MapLibre + OpenFreeMap
    implementation("org.maplibre.gl:android-sdk:11.5.2")
    // Lettura del cartello: modello incluso nell'app, funziona anche senza servizi Google
    implementation("com.google.mlkit:text-recognition:16.0.1")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
