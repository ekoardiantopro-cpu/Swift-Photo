import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/media_file_names.dart';

void main() {
  test(
    'Edited filenames preserve original stem/extension and add one unique character',
    () {
      final names = MediaFileNames.editedCandidates(
        'swift_123.png',
        random: Random(42),
      );
      expect(names.length, 36);
      expect(names.toSet().length, 36);
      for (final name in names) {
        expect(RegExp(r'^swift_123[A-Z0-9]\.png$').hasMatch(name), isTrue);
      }
      expect(names, isNot(contains('swift_123.png')));
      expect(
        MediaFileNames.editedCandidates(
          'swift_123A.png',
        ).every((v) => RegExp(r'^swift_123A[A-Z0-9]\.png$').hasMatch(v)),
        isTrue,
      );
    },
  );
  test('Path components and unsupported extensions are rejected', () {
    for (final name in [
      '../swift.png',
      r'folder\swift.png',
      'photo.jpg',
      '.png',
    ]) {
      expect(() => MediaFileNames.editedCandidates(name), throwsArgumentError);
    }
  });
}
