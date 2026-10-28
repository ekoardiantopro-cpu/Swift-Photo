import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:swift_photo/services/settings_service.dart';
import 'package:swift_photo/models/camera_options.dart';
import 'package:swift_photo/models/watermark_data.dart';
import 'package:swift_photo/models/template_customization.dart';

void main() {
  late Directory directory;
  late SettingsService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'swift_photo_settings_test_',
    );
    service = SettingsService(directoryProvider: () async => directory);
  });
  tearDown(() async {
    if (!directory.absolute.path.startsWith(
      '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}swift_photo_settings_test_',
    )) {
      throw StateError('Unexpected temporary path');
    }
    await directory.delete(recursive: true);
  });
  test(
    'Quality defaults to HD and changes without resetting other preferences',
    () async {
      expect((await service.load()).quality, PhotoQuality.hd);
      await service.update(
        template: MarkTemplate.security,
        enabled: false,
        cloudEnabled: true,
        layout: WatermarkLayout.footer,
      );
      await service.update(quality: PhotoQuality.low);
      final settings = await service.load();
      expect(settings.quality, PhotoQuality.low);
      expect(settings.template, MarkTemplate.security);
      expect(settings.enabled, isFalse);
      expect(settings.cloudEnabled, isTrue);
      expect(settings.layout, WatermarkLayout.footer);
      await service.saveLayout(WatermarkLayout.bottomRight);
      expect((await service.load()).quality, PhotoQuality.low);
      expect(PhotoQuality.low.preset, ResolutionPreset.low);
      expect(PhotoQuality.hd.preset, ResolutionPreset.veryHigh);
    },
  );
  test(
    'Template designs persist independently through unrelated settings changes',
    () async {
      await service.update(
        template: MarkTemplate.classic,
        customization: const TemplateCustomization(
          logoX: .45,
          logoY: .2,
          showAddress: false,
        ),
      );
      await service.update(
        template: MarkTemplate.security,
        customization: const TemplateCustomization(logoWidth: .5),
      );
      await service.update(quality: PhotoQuality.low);
      final settings = await service.load();
      expect(settings.customizations[MarkTemplate.classic]!.logoX, .45);
      expect(
        settings.customizations[MarkTemplate.classic]!.showAddress,
        isFalse,
      );
      expect(settings.customizations[MarkTemplate.security]!.logoWidth, .5);
    },
  );
  test(
    'Legacy settings retain logo/layout and migrate with HD default',
    () async {
      await File(
        '${directory.path}/camera.json',
      ).writeAsString('{"layout":"footer"}');
      await File('${directory.path}/company_logo.image').writeAsBytes([1, 2]);
      final settings = await service.load();
      expect(settings.layout, WatermarkLayout.footer);
      expect(settings.quality, PhotoQuality.hd);
      expect(settings.logo, [1, 2]);
    },
  );
}
