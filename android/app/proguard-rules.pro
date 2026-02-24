# Flutter wrapper proguard rules
# You can add custom rules here if needed.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Ignore warnings for deferred components Play Store references
-dontwarn io.flutter.embedding.**
-dontwarn com.google.android.play.core.**
-dontwarn com.google.errorprone.annotations.**
