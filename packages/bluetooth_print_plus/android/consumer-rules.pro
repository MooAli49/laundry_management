# Keep all classes and interfaces in GPrinter SDK
-keep class com.gprinter.** { *; }
-keep interface com.gprinter.** { *; }
-dontwarn com.gprinter.**

# Keep jzlib compression library packaged in SDKLib.jar
-keep class com.jcraft.jzlib.** { *; }
-dontwarn com.jcraft.jzlib.**

# Explicitly retain CallbackListener interface, its methods, and any implementing class
-keep interface com.gprinter.utils.CallbackListener {
    public *;
}
-keep class * implements com.gprinter.utils.CallbackListener {
    public *;
}

# Keep BluetoothPrintPlus plugin classes, inner classes, and callbacks
-keep class com.example.bluetooth_print_plus.bluetooth_print_plus.** { *; }

# Keep EasyPermissions library
-keep class pub.devrel.easypermissions.** { *; }

# Retain signature and inner-class metadata for native reflection/invocations
-keepattributes Signature,Exceptions,InnerClasses,EnclosingMethod,Deprecated,*Annotation*
