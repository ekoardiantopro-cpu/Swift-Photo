import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swift_photo/services/place_search_service.dart';

void main() {
  test('Type-ahead suggests Bengkulu from a partial query without network', () {
    final service = PlaceSearchService(
      forward: (_) async => throw StateError('Network must not be called'),
    );
    final results = service.suggest('beng');
    expect(results, isNotEmpty);
    expect(results.first.title, 'Bengkulu');
    expect(results.first.address, contains('Kota Bengkulu'));
    expect(results.first.source, PlaceSearchSource.localIndex);
  });

  test('Type-ahead requires two characters and respects its result limit', () {
    final service = PlaceSearchService();
    expect(service.suggest('b'), isEmpty);
    expect(service.suggest('beng', limit: 2), hasLength(2));
  });

  test(
    'Address search trims query and produces a selectable named pin',
    () async {
      final service = PlaceSearchService(
        forward: (query) async {
          expect(query, 'Monas Jakarta');
          return [const Location(latitude: -6.175392, longitude: 106.827153)];
        },
        reverse: (_, _) async => [
          const Placemark(
            street: 'Monas, Gambir',
            subLocality: 'Gambir',
            locality: 'Jakarta',
            country: 'Indonesia',
          ),
        ],
      );
      final results = await service.search('  Monas Jakarta  ');
      expect(results.single.latitude, -6.175392);
      expect(results.single.longitude, 106.827153);
      expect(results.single.address, 'Monas, Gambir, Jakarta, Indonesia');
    },
  );

  test(
    'Online search returns named OpenStreetMap pins and caches the query',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['q'], 'Monas Jakarta');
        expect(request.headers['user-agent'], contains('SwiftPhoto'));
        return http.Response(
          '[{"lat":"-6.175392","lon":"106.827153","display_name":"Monumen Nasional, Jakarta"}]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = PlaceSearchService(
        client: client,
        endpoint: Uri.parse('https://example.test/search'),
      );
      final first = await service.search('Monas Jakarta');
      final second = await service.search('monas jakarta');
      expect(first.single.address, 'Monumen Nasional, Jakarta');
      expect(first.single.source, PlaceSearchSource.openStreetMap);
      expect(second.single.latitude, -6.175392);
      expect(calls, 1);
    },
  );

  test(
    'Search drops invalid and duplicate pins and keeps a bounded result list',
    () async {
      final service = PlaceSearchService(
        forward: (_) async => [
          const Location(latitude: double.nan, longitude: 100),
          const Location(latitude: 91, longitude: 100),
          const Location(latitude: -6, longitude: 106),
          const Location(latitude: -6, longitude: 106),
          const Location(latitude: -7, longitude: 107),
          const Location(latitude: -8, longitude: 108),
          const Location(latitude: -9, longitude: 109),
        ],
        reverse: (_, _) async => [],
      );
      final results = await service.search('Alamat');
      expect(results.map((p) => p.latitude), [-6, -7, -8]);
    },
  );

  test(
    'A reverse lookup failure does not discard a valid search pin',
    () async {
      final service = PlaceSearchService(
        forward: (_) async => [const Location(latitude: 0, longitude: 0)],
        reverse: (_, _) async => throw StateError('Offline'),
      );
      expect((await service.search('Tempat uji')).single.address, 'Tempat uji');
    },
  );

  test(
    'Empty input skips geocoder and no matches return an empty list',
    () async {
      var calls = 0;
      final service = PlaceSearchService(
        forward: (_) async {
          calls++;
          return [];
        },
      );
      expect(await service.search('  '), isEmpty);
      expect(calls, 0);
      expect(await service.search('Tidak ada'), isEmpty);
      expect(calls, 1);
    },
  );
}
