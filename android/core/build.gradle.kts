plugins {
    kotlin("jvm") version "2.0.21"
    kotlin("plugin.serialization") version "2.0.21"
}

repositories {
    maven("https://repo1.maven.org/maven2/")
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testImplementation(kotlin("test"))
}

java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

tasks.test {
    useJUnitPlatform()
    // I test leggono gli stessi file delle città dell'app iPhone
    systemProperty("gatelr.cities", rootDir.resolve("../../Resources/Cities").absolutePath)
    // 1.20.3: i testi di Android nelle 8 lingue (generati da Tools/translations.py)
    systemProperty("gatelr.i18n", rootDir.resolve("../app/src/main/assets/i18n").absolutePath)
    // 2.0.1: i test dei bug Android controllano anche i sorgenti dell'app (manifest, schermate) che il JVM non può aprire
    systemProperty("gatelr.app", rootDir.resolve("../app/src/main").absolutePath)
    testLogging { events("failed"); exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL }
}
