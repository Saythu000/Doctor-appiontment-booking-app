# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# WorkManager
-keep class androidx.work.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# Health Connect Client
-keep class androidx.health.** { *; }
-keep class androidx.health.connect.client.** { *; }
-keep class androidx.health.platform.client.** { *; }

# Security & EncryptedSharedPreferences (flutter_secure_storage)
-keep class androidx.security.crypto.** { *; }

# SQLite / SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }

# Desugaring & Kotlin Coroutines
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn java.lang.invoke.MethodHandles$Lookup
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Suppress generic reflection warnings
-dontwarn io.flutter.embedding.**
