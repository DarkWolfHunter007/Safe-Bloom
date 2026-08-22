# R8 / ProGuard rules for Safe Bloom Production Release

# Preserve generic signatures, annotations, and reflection attributes (Required for Gson TypeToken & Local Notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable

# Suppress warnings for optional Play Core deferred components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Preserve Flutter engine & plugin bindings
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# flutter_local_notifications & Gson precision keep rules (v17.2.x compatibility)
-dontwarn sun.misc.**
-dontwarn com.google.gson.**
-keepclassmembers class * implements com.google.gson.TypeAdapterFactory {
    public <init>(...);
}
-keepclassmembers class * implements com.google.gson.JsonSerializer {
    public <init>(...);
}
-keepclassmembers class * implements com.google.gson.JsonDeserializer {
    public <init>(...);
}
-keepclassmembers enum * { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# flutter_local_notifications models & notification receivers
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }

# Preserve SQLCipher Native & Database Classes
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-keepclassmembers class * extends net.sqlcipher.database.SQLiteOpenHelper {
    public <init>(...);
}

# Preserve AndroidX Security Crypto, KeyStore & Biometrics
-keep class androidx.security.crypto.** { *; }
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Strip all android.util.Log calls in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int println(...);
}
