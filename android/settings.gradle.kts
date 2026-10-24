// GateLR per Android. Il motore (core/) è condiviso: l'app ne usa i sorgenti.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "GateLR"
include(":app")
