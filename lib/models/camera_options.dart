import 'dart:ui';
import 'package:camera/camera.dart';

enum PhotoQuality {
  low('Rendah', 'File ringan, untuk dokumentasi cepat', ResolutionPreset.low),
  medium(
    'Sedang',
    'Seimbang antara detail dan ukuran file',
    ResolutionPreset.medium,
  ),
  hd('HD', 'Detail tinggi, ukuran file lebih besar', ResolutionPreset.veryHigh);

  const PhotoQuality(this.label, this.description, this.preset);
  final String label;
  final String description;
  final ResolutionPreset preset;
}

enum PhotoRatio {
  portrait('3:4', 3 / 4),
  square('1:1', 1),
  full('9:16', 9 / 16),
  original('Asli', null);

  const PhotoRatio(this.label, this.aspectRatio);
  final String label;
  final double? aspectRatio;

  /// The largest centered preview frame for this ratio. The original option
  /// keeps the entire available viewfinder visible.
  Rect previewBounds(Size available) {
    if (available.width <= 0 || available.height <= 0) return Rect.zero;
    final aspect = aspectRatio;
    if (aspect == null) return Offset.zero & available;
    final availableAspect = available.width / available.height;
    final width = availableAspect > aspect
        ? available.height * aspect
        : available.width;
    final height = availableAspect > aspect
        ? available.height
        : available.width / aspect;
    return Rect.fromLTWH(
      (available.width - width) / 2,
      (available.height - height) / 2,
      width,
      height,
    );
  }

  /// Crop the center at the largest available size without stretching pixels.
  Rect cropBounds(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Dimensi foto tidak valid');
    }
    final aspect = aspectRatio;
    if (aspect == null) {
      return Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    }
    final cropWidth = width / height > aspect
        ? (height * aspect).round().clamp(1, width)
        : width;
    final cropHeight = width / height > aspect
        ? height
        : (width / aspect).round().clamp(1, height);
    return Rect.fromLTWH(
      ((width - cropWidth) / 2).floorToDouble(),
      ((height - cropHeight) / 2).floorToDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );
  }
}

class CameraZoomRange {
  const CameraZoomRange(this.minimum, this.maximum)
    : assert(minimum > 0 && maximum >= minimum && maximum < double.infinity);
  final double minimum;
  final double maximum;

  bool supports(double zoom) =>
      zoom.isFinite && zoom >= minimum - 0.001 && zoom <= maximum + 0.001;
  double clamp(double zoom) => zoom.clamp(minimum, maximum).toDouble();
}

class CameraLenses {
  static CameraDescription? primary(
    List<CameraDescription> cameras,
    CameraLensDirection facing,
  ) {
    final matching = cameras
        .where((camera) => camera.lensDirection == facing)
        .toList();
    if (matching.isEmpty) return null;
    for (final type in [CameraLensType.wide, CameraLensType.unknown]) {
      for (final camera in matching) {
        if (camera.lensType == type) return camera;
      }
    }
    return matching.first;
  }

  static CameraDescription? ultraWide(
    List<CameraDescription> cameras,
    CameraLensDirection facing,
  ) {
    final main = primary(cameras, facing);
    for (final camera in cameras) {
      if (camera.lensDirection == facing &&
          camera.lensType == CameraLensType.ultraWide &&
          camera != main) {
        return camera;
      }
    }
    return null;
  }
}
