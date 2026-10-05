# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**

# GPrinter SDKLib
-keep class com.gprinter.** { *; }
-keep interface com.gprinter.** { *; }
-dontwarn com.gprinter.**

# jzlib compression library
-keep class com.jcraft.jzlib.** { *; }
-dontwarn com.jcraft.jzlib.**

# CallbackListener interface and implementations
-keep interface com.gprinter.utils.CallbackListener {
    public *;
}
-keep class * implements com.gprinter.utils.CallbackListener {
    public *;
}

# BluetoothPrintPlus Plugin
-keep class com.example.bluetooth_print_plus.bluetooth_print_plus.** { *; }

# EasyPermissions
-keep class pub.devrel.easypermissions.** { *; }

# Preserve reflection, signature, and inner class metadata
-keepattributes Signature,Exceptions,InnerClasses,EnclosingMethod,Deprecated,*Annotation*
