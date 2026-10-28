import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/watermark_data.dart';
import 'package:swift_photo/models/template_customization.dart';
import 'package:swift_photo/models/camera_options.dart';
import 'package:swift_photo/services/photo_project_service.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'swift_photo_project_test_',
    );
  });
  tearDown(() async {
    final root = Directory.systemTemp.absolute.path;
    final target = directory.absolute.path;
    if (!target.startsWith(
      '$root${Platform.pathSeparator}swift_photo_project_test_',
    )) {
      throw StateError('Unexpected temporary directory');
    }
    await directory.delete(recursive: true);
  });
  test(
    'Legacy flattened photos are detected without changing the image',
    () async {
      final file = File('${directory.path}/legacy.png');
      await file.writeAsBytes([4, 5, 6]);
      expect(await PhotoProjectService().load(file), isNull);
      expect(await file.readAsBytes(), [4, 5, 6]);
    },
  );
  test(
    'Project retains clean source, logo, crop, editable data and edit attribution',
    () async {
      final file = File('${directory.path}/photo.png');
      await file.writeAsBytes([7, 7, 7]);
      final source = Uint8List.fromList([1, 2, 3, 4]);
      final logo = Uint8List.fromList([8, 9]);
      final data = WatermarkData(
        capturedAt: DateTime(2026, 10, 25, 17, 5, 35),
        address: 'Jakarta',
        latitude: -6.175392,
        longitude: 106.827153,
        photoCode: 'TKWL9PWKTN6MTC',
        layout: WatermarkLayout.bottomRight,
        template: MarkTemplate.sheet,
        isManual: true,
        isEdited: true,
        customization: const TemplateCustomization(
          logoX: .4,
          logoY: .2,
          logoOpacity: .5,
          showCoordinates: false,
        ),
        enabled: false,
      );
      await PhotoProjectService().save(
        file,
        source,
        data,
        PhotoRatio.square,
        logo: logo,
      );
      final project = (await PhotoProjectService().load(file))!;
      expect(await project.source.readAsBytes(), source);
      expect(await project.logo!.readAsBytes(), logo);
      expect(project.ratio, PhotoRatio.square);
      expect(project.data.capturedAt, data.capturedAt);
      expect(project.data.address, data.address);
      expect(project.data.latitude, data.latitude);
      expect(project.data.longitude, data.longitude);
      expect(project.data.photoCode, data.photoCode);
      expect(project.data.layout, data.layout);
      expect(project.data.template, data.template);
      expect(project.data.isManual, isTrue);
      expect(project.data.isEdited, isTrue);
      expect(project.data.enabled, isFalse);
      expect(project.data.customization.toJson(), data.customization.toJson());
      expect(project.integrity.verified, isTrue);
    },
  );
}
