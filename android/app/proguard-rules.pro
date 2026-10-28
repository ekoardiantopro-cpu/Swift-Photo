# Flutter and bundled plugins provide their own consumer rules. Keep model
# metadata used by platform serializers and background workers.
-keepattributes *Annotation*
-keepattributes Signature

-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
