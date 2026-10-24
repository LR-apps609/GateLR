# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-keepclassmembers class app.gatelr.core.** { *** Companion; }
-keepclasseswithmembers class app.gatelr.core.** { kotlinx.serialization.KSerializer serializer(...); }
-keep class app.gatelr.core.**$$serializer { *; }
# MapLibre
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**
