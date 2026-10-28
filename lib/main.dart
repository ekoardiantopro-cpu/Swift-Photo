import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/startup_screen.dart';
import 'widgets/interactive_effects.dart';
import 'services/cloud_sync_service.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Barlow Condensed',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SwiftPhotoApp());
  AppLifecycleListener(onResume: CloudSyncService.resumeSafely);
  CloudSyncService.resumeSafely();
}

class SwiftPhotoApp extends StatelessWidget {
  const SwiftPhotoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Swift Photo',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF27C76F)
              : const Color(0xFFD2D8E0),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF078EED),
        primary: const Color(0xFF078EED),
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF171A1F),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E3E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E3E8)),
        ),
      ),
      cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
    ),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: InteractiveEffects(child: child ?? const SizedBox.shrink()),
    ),
    home: const AppEntry(),
  );
}
