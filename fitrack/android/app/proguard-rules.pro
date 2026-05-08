# Flutter secure storage — keep all classes so R8 doesn't strip them
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Keep Flutter and Dart runtime
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Dio / OkHttp networking classes
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# TensorFlow Lite (tflite_flutter) — GPU delegate classes are referenced at
# runtime but not present in all build variants; suppress R8 warnings.
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
