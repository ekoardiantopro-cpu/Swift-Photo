import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationSnapshot {
  const LocationSnapshot(this.latitude, this.longitude, this.address);
  final double? latitude;
  final double? longitude;
  final String address;
}

class LocationService {
  Future<LocationSnapshot> read() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationSnapshot(null, null, 'GPS perangkat nonaktif');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationSnapshot(
          null,
          null,
          'Izin lokasi tidak diberikan',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      var address = 'Alamat tidak tersedia (offline)';
      try {
        final places = await Geocoding()
            .placemarkFromCoordinates(position.latitude, position.longitude)
            .timeout(const Duration(seconds: 5));
        if (places.isNotEmpty) {
          final p = places.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].whereType<String>().where((s) => s.isNotEmpty).toSet();
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {
        // Koordinat tetap dapat dipakai tanpa layanan alamat/internet.
      }
      return LocationSnapshot(position.latitude, position.longitude, address);
    } catch (_) {
      return const LocationSnapshot(
        null,
        null,
        'GPS gagal / waktu tunggu habis',
      );
    }
  }
}
