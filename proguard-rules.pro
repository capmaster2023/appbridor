# Capacitor / plugins natifs requis
-keep class com.getcapacitor.** { *; }
-keep @com.getcapacitor.annotation.CapacitorPlugin class * { *; }
-keepclassmembers class * {
    @com.getcapacitor.PluginMethod <methods>;
}
-keep class androidx.security.crypto.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.security.crypto.**
-dontwarn androidx.media3.**
-keep class org.json.** { *; }
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
}
-repackageclasses ''
-allowaccessmodification
-overloadaggressively
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
