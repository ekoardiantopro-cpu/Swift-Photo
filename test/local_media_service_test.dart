import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/services/local_media_service.dart';

void main() {
  late Directory directory;
  late LocalMediaService service;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'swift_photo_media_test_',
    );
    service = LocalMediaService(documentsProvider: () async => directory);
  });
  tearDown(() async {
    if (!directory.absolute.path.startsWith(
      '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}swift_photo_media_test_',
    )) {
      throw StateError('Unexpected temporary path');
    }
    await directory.delete(recursive: true);
  });
  test(
    'Saving repeated edits adds one character without overwriting source or earlier edits',
    () async {
      final source = await service.saveInternal(Uint8List.fromList([1, 2]));
      final a = await service.saveInternal(
        Uint8List.fromList([3, 4]),
        editedFrom: source,
      );
      final b = await service.saveInternal(
        Uint8List.fromList([5, 6]),
        editedFrom: source,
      );
      expect(a.path, isNot(b.path));
      for (final file in [a, b]) {
        final original = source.uri.pathSegments.last;
        final name = file.uri.pathSegments.last;
        expect(name.length, original.length + 1);
        expect(
          name.substring(0, original.length - 4),
          original.substring(0, original.length - 4),
        );
      }
      expect(await source.readAsBytes(), [1, 2]);
      expect(await a.readAsBytes(), [3, 4]);
      expect(await b.readAsBytes(), [5, 6]);
      await a.setLastModified(DateTime(2026, 1, 3));
      await b.setLastModified(DateTime(2026, 1, 1));
      await source.setLastModified(DateTime(2026, 1, 2));
      final photos = await service.listPhotos();
      expect(photos.map((f) => f.uri), [a.uri, source.uri, b.uri]);
    },
  );
}
