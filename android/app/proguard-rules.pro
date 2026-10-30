# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase / Google Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Other common native plugins (TTS, Image Compress, Speech)
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.simform.flutter_image_compress.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }

-dontwarn io.flutter.embedding.**
-dontwarn com.google.firebase.**
