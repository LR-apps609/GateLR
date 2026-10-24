# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-keepclassmembers class app.gatelr.** { *** Companion; }
-keepclasseswithmembers class app.gatelr.** { kotlinx.serialization.KSerializer serializer(...); }
-keep class app.gatelr.**$$serializer { *; }
# MapLibre
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**
