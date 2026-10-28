import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/camera_options.dart';

void main() {
  test(
    'Portrait, square and full ratios crop the sensor center without upscaling',
    () {
      expect(
        PhotoRatio.portrait.cropBounds(720, 1280),
        const Rect.fromLTWH(0, 160, 720, 960),
      );
      expect(
        PhotoRatio.square.cropBounds(720, 1280),
        const Rect.fromLTWH(0, 280, 720, 720),
      );
      expect(
        PhotoRatio.full.cropBounds(720, 1280),
        const Rect.fromLTWH(0, 0, 720, 1280),
      );
      expect(
        PhotoRatio.original.cropBounds(720, 1280),
        const Rect.fromLTWH(0, 0, 720, 1280),
      );
    },
  );

  test(
    'Landscape source is cropped to portrait and tiny images remain valid',
    () {
      expect(
        PhotoRatio.portrait.cropBounds(4000, 3000),
        const Rect.fromLTWH(875, 0, 2250, 3000),
      );
      expect(PhotoRatio.portrait.cropBounds(1, 1).size, const Size(1, 1));
      expect(() => PhotoRatio.square.cropBounds(0, 100), throwsArgumentError);
    },
  );

  test('Ratio preview frames are centered and match the selected output', () {
    const viewfinder = Size(360, 640);
    expect(
      PhotoRatio.portrait.previewBounds(viewfinder),
      const Rect.fromLTWH(0, 80, 360, 480),
    );
    expect(
      PhotoRatio.square.previewBounds(viewfinder),
      const Rect.fromLTWH(0, 140, 360, 360),
    );
    expect(
      PhotoRatio.full.previewBounds(viewfinder),
      const Rect.fromLTWH(0, 0, 360, 640),
    );
    expect(
      PhotoRatio.original.previewBounds(viewfinder),
      Offset.zero & viewfinder,
    );
  });

  test(
    'Unsupported ultra-wide zoom is never advertised as a digital zoom-out',
    () {
      const normal = CameraZoomRange(1, 8);
      const logicalUltraWide = CameraZoomRange(0.5, 8);
      expect(normal.supports(0.5), isFalse);
      expect(normal.supports(2), isTrue);
      expect(normal.supports(double.nan), isFalse);
      expect(normal.clamp(20), 8);
      expect(logicalUltraWide.supports(0.5), isTrue);
    },
  );

  const ultra = CameraDescription(
    name: 'ultra',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
    lensType: CameraLensType.ultraWide,
  );
  const wide = CameraDescription(
    name: 'wide',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
    lensType: CameraLensType.wide,
  );
  const front = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
    lensType: CameraLensType.wide,
  );

  test(
    'Normal camera uses the wide lens and finds a distinct ultra-wide lens',
    () {
      expect(
        CameraLenses.primary([ultra, front, wide], CameraLensDirection.back),
        wide,
      );
      expect(
        CameraLenses.ultraWide([ultra, front, wide], CameraLensDirection.back),
        ultra,
      );
      expect(
        CameraLenses.primary([ultra, front, wide], CameraLensDirection.front),
        front,
      );
    },
  );

  test(
    'Missing front camera or distinct ultra-wide lens is reported honestly',
    () {
      expect(CameraLenses.primary([wide], CameraLensDirection.front), isNull);
      expect(CameraLenses.ultraWide([wide], CameraLensDirection.back), isNull);
      expect(CameraLenses.ultraWide([ultra], CameraLensDirection.back), isNull);
    },
  );
}
