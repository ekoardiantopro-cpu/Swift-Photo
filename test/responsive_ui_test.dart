import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/screens/startup_screen.dart';
import 'package:swift_photo/screens/template_designer_screen.dart';
import 'package:swift_photo/screens/edit_watermark_sheet.dart';
import 'package:swift_photo/screens/camera_navigation_drawer.dart';
import 'package:swift_photo/models/watermark_data.dart';
import 'package:swift_photo/widgets/interactive_effects.dart';
import 'package:swift_photo/widgets/animated_swift_bird.dart';

void main() {
  testWidgets('Splash waits for first frame and completes within one second', (
    tester,
  ) async {
    final ready = Completer<void>();
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          firstFrameReady: ready.future,
          onComplete: () => finished++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(finished, 0);
    ready.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(finished, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets('Splash, template controls, catalog and drawer fit $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(home: StartupScreen(onComplete: () => finished++)),
      );
      expect(find.text('Snap for Proof'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.widget<AnimatedSwiftBird>(find.byType(AnimatedSwiftBird)).phase,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(finished, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: TemplateDesignerScreen(
            data: WatermarkData(capturedAt: DateTime(2026)),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditWatermarkSheet(
              layout: WatermarkLayout.bottomLeft,
              hasLogo: false,
              template: MarkTemplate.classic,
              enabled: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraNavigationDrawer(
              onSelected: (_) {},
              onClose: () {},
              mode: 'Real',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Small screen accommodates enlarged accessibility text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget host(Widget child) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: child,
    );
    await tester.pumpWidget(
      host(
        TemplateDesignerScreen(data: WatermarkData(capturedAt: DateTime(2026))),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: EditWatermarkSheet(
            layout: WatermarkLayout.bottomLeft,
            hasLogo: false,
            template: MarkTemplate.classic,
            enabled: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(
        Scaffold(
          body: CameraNavigationDrawer(
            onSelected: (_) {},
            onClose: () {},
            mode: 'Real',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Dragging logo changes normalized saved placement; Save returns config',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.red, BlendMode.src);
      final picture = recorder.endRecording();
      final logo = (await tester.runAsync(() => picture.toImage(180, 60)))!;
      picture.dispose();
      TemplateDesignResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<TemplateDesignResult>(
                        MaterialPageRoute(
                          builder: (_) => TemplateDesignerScreen(
                            data: WatermarkData(capturedAt: DateTime(2026)),
                            logo: logo,
                          ),
                        ),
                      );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final preview = tester.getSize(
        find.byKey(const ValueKey('template-preview')),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('draggable-logo'))),
      );
      await gesture.moveBy(const Offset(30, -20));
      await gesture.moveBy(const Offset(30, -20));
      await gesture.moveBy(const Offset(30, -20));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(
        result!.customization.logoX,
        closeTo(.05 + 90 / preview.width, .001),
      );
      expect(
        result!.customization.logoY,
        closeTo(.60 - 60 / preview.height, .001),
      );
      await tester.pumpWidget(const SizedBox());
      logo.dispose();
    },
  );
  testWidgets(
    'Reduced motion stays still and global effects preserve tap behavior',
    (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: InteractiveEffects(
              child: Scaffold(
                body: TextButton(
                  onPressed: () => pressed++,
                  child: const Text('Tap'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap'));
      await tester.pump();
      expect(pressed, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StartupScreen(onComplete: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<AnimatedSwiftBird>(find.byType(AnimatedSwiftBird)).phase,
        0,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
