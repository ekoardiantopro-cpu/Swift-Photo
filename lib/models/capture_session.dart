enum CaptureMode { real, fake }

class CaptureSession {
  const CaptureSession.real()
    : mode = CaptureMode.real,
      manualTime = null,
      latitude = null,
      longitude = null,
      address = null;

  CaptureSession.fake({
    required DateTime time,
    required double latitude,
    required double longitude,
    required String address,
  }) : mode = CaptureMode.fake,
       manualTime = time,
       latitude = latitude,
       longitude = longitude,
       address = address.trim() {
    if (!validCoordinates(latitude, longitude) || address.trim().isEmpty) {
      throw ArgumentError('Pin dan alamat harus valid.');
    }
  }

  final CaptureMode mode;
  final DateTime? manualTime;
  final double? latitude;
  final double? longitude;
  final String? address;

  bool get isManual => mode == CaptureMode.fake;
  DateTime timeAt(DateTime deviceTime) => manualTime ?? deviceTime;

  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
