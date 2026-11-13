# ProGuard/R8 Rules for Sangh Ledger

# Preserve SQLCipher native JNI bindings and database classes
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }
-dontwarn net.sqlcipher.**

# Preserve Sqflite SQLCipher plugin
-keep class com.davidmartos96.sqflite_sqlcipher.** { *; }
-dontwarn com.davidmartos96.sqflite_sqlcipher.**

# Preserve Flutter Secure Storage (Android Keystore / EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Preserve Flutter engine & plugin bindings
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Cryptography & Local Auth
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Play Store deferred component stubs (suppress unused warnings)
-dontwarn com.google.android.play.core.**

# Strip sensitive debug logs from release APK
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
