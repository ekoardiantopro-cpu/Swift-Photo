import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:swift_photo/models/watermark_data.dart';
import 'package:swift_photo/models/camera_options.dart';
import 'package:swift_photo/models/watermark_regions.dart';
import 'package:swift_photo/models/template_customization.dart';
import 'package:swift_photo/services/watermark_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('BarlowCondensed')
      ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-Regular.ttf'));
    await font.load();
  });

  test('Timestamp menggunakan tanggal dan jam yang dibekukan saat capture', () {
    final data = WatermarkData(capturedAt: DateTime(2026, 10, 25, 9, 5, 3));
    expect(data.timestamp, '25/10/2026 - 09:05:03');
    expect(data.coordinates, 'GPS tidak tersedia');
  });

  test(
    'Square export crops photo pixels before applying the complete watermark',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.green, BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1000, 300),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 1700, 1000, 300),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(1000, 2000);
      picture.dispose();
      final png = (await source.toByteData(format: ui.ImageByteFormat.png))!;
      source.dispose();
      final rendered = await WatermarkRenderer().render(
        png.buffer.asUint8List(),
        WatermarkData(capturedAt: DateTime(2026)),
        null,
        ratio: PhotoRatio.square,
      );
      final codec = await ui.instantiateImageCodec(rendered);
      final output = (await codec.getNextFrame()).image;
      expect(output.width, 1000);
      expect(output.height, 1000);
      final pixels = (await output.toByteData())!;
      final sample = (100 * output.width + 500) * 4;
      expect(
        pixels.getUint8(sample),
        76,
      ); // Center green remains, red/blue edges are cropped.
      expect(pixels.getUint8(sample + 1), 175);
      expect(pixels.getUint8(sample + 2), 80);
      final divider = (730 * output.width + 319) * 4;
      expect(pixels.getUint8(divider), 255);
      expect(pixels.getUint8(divider + 1), 203);
      output.dispose();
      codec.dispose();
    },
  );

  test('Disabled watermark leaves every source pixel unchanged', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.green, BlendMode.src);
    final picture = recorder.endRecording();
    final source = await picture.toImage(100, 150);
    picture.dispose();
    final sourcePixels = (await source.toByteData())!.buffer.asUint8List();
    final png = (await source.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final rendered = await WatermarkRenderer().render(
      png,
      WatermarkData(capturedAt: DateTime(2026), enabled: false),
      null,
    );
    final codec = await ui.instantiateImageCodec(rendered);
    final output = (await codec.getNextFrame()).image;
    expect(
      (await output.toByteData())!.buffer.asUint8List(),
      orderedEquals(sourcePixels),
    );
    output.dispose();
    codec.dispose();
    source.dispose();
  });

  test(
    'Dragged transparent logo renders at normalized photo position',
    () async {
      final sourceRecorder = ui.PictureRecorder();
      Canvas(sourceRecorder).drawColor(Colors.white, BlendMode.src);
      final sourcePicture = sourceRecorder.endRecording();
      final source = await sourcePicture.toImage(1000, 1000);
      sourcePicture.dispose();
      final png = (await source.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      source.dispose();
      final logoRecorder = ui.PictureRecorder();
      Canvas(logoRecorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
      final logoPicture = logoRecorder.endRecording();
      final logo = await logoPicture.toImage(100, 100);
      logoPicture.dispose();
      final rendered = await WatermarkRenderer().render(
        png,
        WatermarkData(
          capturedAt: DateTime(2026),
          customization: const TemplateCustomization(
            logoX: .7,
            logoY: .1,
            logoWidth: .2,
            logoOpacity: .5,
          ),
        ),
        logo,
      );
      final codec = await ui.instantiateImageCodec(rendered);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData())!;
      final index = (200 * 1000 + 800) * 4;
      expect(pixels.getUint8(index), 255);
      expect(pixels.getUint8(index + 1), closeTo(127, 1));
      expect(pixels.getUint8(index + 2), closeTo(127, 1));
      image.dispose();
      codec.dispose();
      logo.dispose();
    },
  );

  test('All reference presets render with bounded editable fields', () async {
    const canvasSize = 360;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.grey, BlendMode.src);
    final picture = recorder.endRecording();
    final source = await picture.toImage(canvasSize, canvasSize);
    picture.dispose();
    final png = (await source.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    source.dispose();
    for (final template in MarkTemplate.values) {
      final data = WatermarkData(
        capturedAt: DateTime(2026),
        template: template,
        address: 'Jalan Merdeka, Jakarta',
        latitude: -6.175392,
        longitude: 106.827153,
      );
      final output = await WatermarkRenderer().render(png, data, null);
      expect(output.length, greaterThan(png.length), reason: template.name);
      const regionWidth = 1000.0;
      final regions = WatermarkRegions.forData(data, regionWidth);
      expect(regions.containsKey(WatermarkField.code), isTrue);
      for (final region in regions.values) {
        expect(region.left, greaterThanOrEqualTo(0));
        expect(region.right, lessThanOrEqualTo(regionWidth));
        expect(region.top, greaterThanOrEqualTo(0));
        expect(region.bottom, lessThanOrEqualTo(regionWidth));
      }
    }
  });

  for (final layout in WatermarkLayout.values) {
    test(
      'Render ${layout.name} membakar watermark ke file resolusi asli',
      () async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.white, BlendMode.src);
        final picture = recorder.endRecording();
        final source = await picture.toImage(1000, 1500);
        picture.dispose();
        final png = await source.toByteData(format: ui.ImageByteFormat.png);
        source.dispose();
        final rendered = await WatermarkRenderer().render(
          png!.buffer.asUint8List(),
          WatermarkData(capturedAt: DateTime(2026), layout: layout),
          null,
        );
        final codec = await ui.instantiateImageCodec(rendered);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 1000);
        expect(image.height, 1500);
        final rgba = (await image.toByteData())!;
        int red(int x, int y) => rgba.getUint8((y * image.width + x) * 4);
        expect(red(500, 100), 255); // Foto di luar watermark tetap putih.
        expect(
          red(10, 1450),
          lessThan(255),
        ); // Gradien meningkatkan keterbacaan.
        final dividerX = layout == WatermarkLayout.bottomRight ? 451 : 319;
        final divider = (1230 * image.width + dividerX) * 4;
        expect(rgba.getUint8(divider), 255);
        expect(rgba.getUint8(divider + 1), 203);
        expect(rgba.getUint8(divider + 2), 48);
        image.dispose();
        codec.dispose();
      },
    );
  }
}
