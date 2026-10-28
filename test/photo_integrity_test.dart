import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/watermark_data.dart';
import 'package:swift_photo/services/photo_integrity_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('swift_integrity_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('integrity record verifies photo, source, and metadata', () async {
    final photo = await File(
      '${directory.path}/photo.png',
    ).writeAsBytes([1, 2, 3]);
    final project = await Directory('${photo.path}.project').create();
    final source = await File(
      '${project.path}/source.image',
    ).writeAsBytes([4, 5]);
    final metadata = await File(
      '${project.path}/data.json',
    ).writeAsString('{}');
    final service = PhotoIntegrityService();
    await service.write(
      photo: photo,
      source: source,
      metadata: metadata,
      data: WatermarkData(capturedAt: DateTime(2026, 10, 28)),
    );

    final report = await service.verify(photo);
    expect(report.state, PhotoIntegrityState.verified);
    expect(report.integrityId, hasLength(16));
  });

  test('integrity record detects a changed rendered photo', () async {
    final photo = await File(
      '${directory.path}/photo.png',
    ).writeAsBytes([1, 2, 3]);
    final project = await Directory('${photo.path}.project').create();
    final source = await File(
      '${project.path}/source.image',
    ).writeAsBytes([4, 5]);
    final metadata = await File(
      '${project.path}/data.json',
    ).writeAsString('{}');
    final service = PhotoIntegrityService();
    await service.write(
      photo: photo,
      source: source,
      metadata: metadata,
      data: WatermarkData(capturedAt: DateTime(2026, 10, 28)),
    );
    await photo.writeAsBytes([9, 9, 9]);

    expect((await service.verify(photo)).state, PhotoIntegrityState.changed);
  });
}
