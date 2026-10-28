import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/capture_session.dart';
import 'package:swift_photo/models/watermark_data.dart';

void main() {
  test('Real follows the device clock each time a photo is taken', () {
    const session = CaptureSession.real();
    final first = DateTime(2026, 10, 25, 10);
    final next = first.add(const Duration(minutes: 10));
    expect(session.timeAt(first), first);
    expect(session.timeAt(next), next);
    expect(session.isManual, isFalse);
  });

  test('Fake preserves the explicitly selected time and pin', () {
    final manual = DateTime(2026, 10, 24, 17, 5);
    final session = CaptureSession.fake(
      time: manual,
      latitude: -3.2,
      longitude: 101.7,
      address: '  Ketahun, Bengkulu  ',
    );
    expect(session.timeAt(DateTime(2026, 11, 1)), manual);
    expect(session.latitude, -3.2);
    expect(session.longitude, 101.7);
    expect(session.address, 'Ketahun, Bengkulu');
    expect(session.isManual, isTrue);
    final data = WatermarkData(capturedAt: session.timeAt(DateTime.now()));
    expect(data.clock, '17:05');
    expect(data.longDate, '24 Oktober 2026');
    expect(data.weekday, 'Sabtu');
  });

  test('Manual pin rejects invalid coordinates and empty addresses', () {
    for (final value in [double.nan, double.infinity, -91.0, 91.0]) {
      expect(
        () => CaptureSession.fake(
          time: DateTime(2026),
          latitude: value,
          longitude: 100,
          address: 'Lokasi',
        ),
        throwsArgumentError,
      );
    }
    expect(CaptureSession.validCoordinates(0, 0), isTrue);
    expect(CaptureSession.validCoordinates(0, 181), isFalse);
    expect(
      () => CaptureSession.fake(
        time: DateTime(2026),
        latitude: 0,
        longitude: 0,
        address: ' ',
      ),
      throwsArgumentError,
    );
  });
}
