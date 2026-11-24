# DESI GUESS R8 / ProGuard Rules
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class com.desiguess.app.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
