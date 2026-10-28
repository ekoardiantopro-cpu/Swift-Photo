import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../models/capture_session.dart';

enum PlaceSearchSource { device, localIndex, openStreetMap }

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.title,
    this.source = PlaceSearchSource.device,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String? title;
  final PlaceSearchSource source;
}

class _IndexedPlace {
  const _IndexedPlace(
    this.title,
    this.address,
    this.latitude,
    this.longitude, [
    this.aliases = const <String>[],
  ]);

  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> aliases;
}

/// Place search for the Manual capture screen.
///
/// Type-ahead suggestions come from a compact on-device index. Network search
/// is only sent after an explicit submit; the public OpenStreetMap endpoint is
/// deliberately never used as an autocomplete service.
class PlaceSearchService {
  PlaceSearchService({
    this.forward,
    Future<List<Placemark>> Function(double, double)? reverse,
    http.Client? client,
    Uri? endpoint,
  }) : _reverse =
           reverse ??
           ((lat, lng) => Geocoding().placemarkFromCoordinates(lat, lng)),
       _providedClient = client,
       _fixedEndpoint = endpoint;

  static const _defaultEndpoint = 'https://nominatim.openstreetmap.org/search';
  static const _configurationUrl =
      'https://swift-photo.web.app/location-search.json';
  static const _userAgent =
      'SwiftPhoto/0.1.0 (mobile; contact: ekoardianto.pro@gmail.com)';
  static Future<void> _requestGate = Future<void>.value();
  static DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  static Uri? _configuredEndpoint;
  static DateTime? _configurationReadAt;

  final Future<List<Location>> Function(String)? forward;
  final Future<List<Placemark>> Function(double, double) _reverse;
  final http.Client? _providedClient;
  final Uri? _fixedEndpoint;
  http.Client? _ownedClient;
  final LinkedHashMap<String, List<PlaceSearchResult>> _cache =
      LinkedHashMap<String, List<PlaceSearchResult>>();

  http.Client get _client =>
      _providedClient ?? (_ownedClient ??= http.Client());

  static const _indexedPlaces = <_IndexedPlace>[
    _IndexedPlace(
      'Banda Aceh',
      'Kota Banda Aceh, Aceh, Indonesia',
      5.5483,
      95.3238,
      ['aceh'],
    ),
    _IndexedPlace(
      'Medan',
      'Kota Medan, Sumatera Utara, Indonesia',
      3.5952,
      98.6722,
      ['sumatera utara', 'sumut'],
    ),
    _IndexedPlace(
      'Padang',
      'Kota Padang, Sumatera Barat, Indonesia',
      -0.9471,
      100.4172,
      ['sumatera barat', 'sumbar'],
    ),
    _IndexedPlace(
      'Pekanbaru',
      'Kota Pekanbaru, Riau, Indonesia',
      0.5071,
      101.4478,
      ['riau'],
    ),
    _IndexedPlace(
      'Tanjung Pinang',
      'Kota Tanjung Pinang, Kepulauan Riau, Indonesia',
      0.9186,
      104.4665,
      ['kepulauan riau', 'kepri'],
    ),
    _IndexedPlace('Jambi', 'Kota Jambi, Jambi, Indonesia', -1.6101, 103.6131),
    _IndexedPlace(
      'Palembang',
      'Kota Palembang, Sumatera Selatan, Indonesia',
      -2.9761,
      104.7754,
      ['sumatera selatan', 'sumsel'],
    ),
    _IndexedPlace(
      'Bengkulu',
      'Kota Bengkulu, Bengkulu, Indonesia',
      -3.7928,
      102.2608,
      ['provinsi bengkulu'],
    ),
    _IndexedPlace(
      'Bengkulu Utara',
      'Kabupaten Bengkulu Utara, Bengkulu, Indonesia',
      -3.4210,
      102.1630,
      ['argamakmur', 'arga makmur'],
    ),
    _IndexedPlace(
      'Bengkulu Selatan',
      'Kabupaten Bengkulu Selatan, Bengkulu, Indonesia',
      -4.3248,
      103.0357,
      ['manna'],
    ),
    _IndexedPlace(
      'Bengkulu Tengah',
      'Kabupaten Bengkulu Tengah, Bengkulu, Indonesia',
      -3.7310,
      102.3570,
    ),
    _IndexedPlace(
      'Bandar Lampung',
      'Kota Bandar Lampung, Lampung, Indonesia',
      -5.3971,
      105.2668,
      ['lampung'],
    ),
    _IndexedPlace(
      'Pangkal Pinang',
      'Kota Pangkal Pinang, Kepulauan Bangka Belitung, Indonesia',
      -2.1316,
      106.1169,
      ['bangka belitung', 'babel'],
    ),
    _IndexedPlace('Jakarta', 'DKI Jakarta, Indonesia', -6.2088, 106.8456, [
      'dki jakarta',
    ]),
    _IndexedPlace(
      'Bandung',
      'Kota Bandung, Jawa Barat, Indonesia',
      -6.9175,
      107.6191,
      ['jawa barat', 'jabar'],
    ),
    _IndexedPlace(
      'Semarang',
      'Kota Semarang, Jawa Tengah, Indonesia',
      -6.9667,
      110.4167,
      ['jawa tengah', 'jateng'],
    ),
    _IndexedPlace(
      'Yogyakarta',
      'Daerah Istimewa Yogyakarta, Indonesia',
      -7.7956,
      110.3695,
      ['jogja', 'diy'],
    ),
    _IndexedPlace(
      'Surabaya',
      'Kota Surabaya, Jawa Timur, Indonesia',
      -7.2575,
      112.7521,
      ['jawa timur', 'jatim'],
    ),
    _IndexedPlace(
      'Serang',
      'Kota Serang, Banten, Indonesia',
      -6.1201,
      106.1503,
      ['banten'],
    ),
    _IndexedPlace(
      'Denpasar',
      'Kota Denpasar, Bali, Indonesia',
      -8.6500,
      115.2167,
      ['bali'],
    ),
    _IndexedPlace(
      'Mataram',
      'Kota Mataram, Nusa Tenggara Barat, Indonesia',
      -8.5833,
      116.1167,
      ['ntb'],
    ),
    _IndexedPlace(
      'Kupang',
      'Kota Kupang, Nusa Tenggara Timur, Indonesia',
      -10.1772,
      123.6070,
      ['ntt'],
    ),
    _IndexedPlace(
      'Pontianak',
      'Kota Pontianak, Kalimantan Barat, Indonesia',
      -0.0263,
      109.3425,
      ['kalimantan barat', 'kalbar'],
    ),
    _IndexedPlace(
      'Palangka Raya',
      'Kota Palangka Raya, Kalimantan Tengah, Indonesia',
      -2.2161,
      113.9139,
      ['kalimantan tengah', 'kalteng'],
    ),
    _IndexedPlace(
      'Banjarmasin',
      'Kota Banjarmasin, Kalimantan Selatan, Indonesia',
      -3.3186,
      114.5944,
      ['kalimantan selatan', 'kalsel'],
    ),
    _IndexedPlace(
      'Samarinda',
      'Kota Samarinda, Kalimantan Timur, Indonesia',
      -0.5022,
      117.1536,
      ['kalimantan timur', 'kaltim'],
    ),
    _IndexedPlace(
      'Tanjung Selor',
      'Tanjung Selor, Kalimantan Utara, Indonesia',
      2.8375,
      117.3653,
      ['kalimantan utara', 'kaltara'],
    ),
    _IndexedPlace(
      'Manado',
      'Kota Manado, Sulawesi Utara, Indonesia',
      1.4748,
      124.8421,
      ['sulawesi utara', 'sulut'],
    ),
    _IndexedPlace(
      'Gorontalo',
      'Kota Gorontalo, Gorontalo, Indonesia',
      0.5435,
      123.0568,
    ),
    _IndexedPlace(
      'Palu',
      'Kota Palu, Sulawesi Tengah, Indonesia',
      -0.8986,
      119.8506,
      ['sulawesi tengah', 'sulteng'],
    ),
    _IndexedPlace(
      'Makassar',
      'Kota Makassar, Sulawesi Selatan, Indonesia',
      -5.1477,
      119.4327,
      ['sulawesi selatan', 'sulsel'],
    ),
    _IndexedPlace(
      'Mamuju',
      'Kabupaten Mamuju, Sulawesi Barat, Indonesia',
      -2.6774,
      118.8867,
      ['sulawesi barat', 'sulbar'],
    ),
    _IndexedPlace(
      'Kendari',
      'Kota Kendari, Sulawesi Tenggara, Indonesia',
      -3.9985,
      122.5120,
      ['sulawesi tenggara', 'sultra'],
    ),
    _IndexedPlace('Ambon', 'Kota Ambon, Maluku, Indonesia', -3.6954, 128.1814, [
      'maluku',
    ]),
    _IndexedPlace(
      'Ternate',
      'Kota Ternate, Maluku Utara, Indonesia',
      0.7893,
      127.3757,
      ['maluku utara', 'malut'],
    ),
    _IndexedPlace(
      'Manokwari',
      'Kabupaten Manokwari, Papua Barat, Indonesia',
      -0.8615,
      134.0620,
      ['papua barat'],
    ),
    _IndexedPlace(
      'Sorong',
      'Kota Sorong, Papua Barat Daya, Indonesia',
      -0.8762,
      131.2558,
      ['papua barat daya'],
    ),
    _IndexedPlace(
      'Jayapura',
      'Kota Jayapura, Papua, Indonesia',
      -2.5916,
      140.6690,
      ['papua'],
    ),
    _IndexedPlace(
      'Nabire',
      'Kabupaten Nabire, Papua Tengah, Indonesia',
      -3.3667,
      135.4833,
      ['papua tengah'],
    ),
    _IndexedPlace(
      'Wamena',
      'Wamena, Papua Pegunungan, Indonesia',
      -4.0959,
      138.9465,
      ['papua pegunungan'],
    ),
    _IndexedPlace(
      'Merauke',
      'Kabupaten Merauke, Papua Selatan, Indonesia',
      -8.4932,
      140.4018,
      ['papua selatan'],
    ),
  ];

  List<PlaceSearchResult> suggest(String text, {int limit = 6}) {
    final query = text.trim().toLowerCase();
    if (query.length < 2 || limit <= 0) return const [];
    final ranked = <({int rank, int index, _IndexedPlace place})>[];
    for (var index = 0; index < _indexedPlaces.length; index++) {
      final place = _indexedPlaces[index];
      final title = place.title.toLowerCase();
      final searchable = <String>[
        title,
        place.address.toLowerCase(),
        ...place.aliases.map((value) => value.toLowerCase()),
      ];
      var rank = 99;
      if (title == query) {
        rank = 0;
      } else if (title.startsWith(query)) {
        rank = 1;
      } else if (searchable.any(
        (value) =>
            value.split(RegExp(r'\s+')).any((word) => word.startsWith(query)),
      )) {
        rank = 2;
      } else if (searchable.any((value) => value.contains(query))) {
        rank = 3;
      }
      if (rank < 99) ranked.add((rank: rank, index: index, place: place));
    }
    ranked.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.index.compareTo(b.index);
    });
    return ranked
        .take(limit)
        .map((entry) {
          final place = entry.place;
          return PlaceSearchResult(
            latitude: place.latitude,
            longitude: place.longitude,
            title: place.title,
            address: place.address,
            source: PlaceSearchSource.localIndex,
          );
        })
        .toList(growable: false);
  }

  Future<List<PlaceSearchResult>> search(String text) async {
    final query = text.trim();
    if (query.isEmpty) return [];
    final cacheKey = query.toLowerCase();
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached;
    }

    late List<PlaceSearchResult> results;
    if (forward != null) {
      results = await _searchDevice(query, forward!);
    } else {
      try {
        results = await _searchOpenStreetMap(query);
      } catch (_) {
        results = await _searchDevice(
          query,
          (value) => Geocoding().locationFromAddress(value),
        );
      }
    }
    _cache[cacheKey] = List<PlaceSearchResult>.unmodifiable(results);
    while (_cache.length > 20) {
      _cache.remove(_cache.keys.first);
    }
    return results;
  }

  Future<List<PlaceSearchResult>> _searchOpenStreetMap(String query) async {
    await _waitForRequestSlot();
    final endpoint = await _resolveEndpoint();
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
        'accept-language': 'id',
      },
    );
    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Accept-Language': 'id,en;q=0.8',
            'User-Agent': _userAgent,
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Place search HTTP ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) throw const FormatException('Invalid place response');
    final seen = <String>{};
    final results = <PlaceSearchResult>[];
    for (final item in body.whereType<Map>()) {
      final latitude = double.tryParse('${item['lat']}');
      final longitude = double.tryParse('${item['lon']}');
      final address = '${item['display_name'] ?? ''}'.trim();
      if (latitude == null ||
          longitude == null ||
          address.isEmpty ||
          !CaptureSession.validCoordinates(latitude, longitude) ||
          !seen.add(
            '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
          )) {
        continue;
      }
      results.add(
        PlaceSearchResult(
          latitude: latitude,
          longitude: longitude,
          title: '${item['name'] ?? ''}'.trim().isEmpty
              ? null
              : '${item['name']}'.trim(),
          address: address,
          source: PlaceSearchSource.openStreetMap,
        ),
      );
      if (results.length == 5) break;
    }
    return results;
  }

  Future<Uri> _resolveEndpoint() async {
    if (_fixedEndpoint != null) return _fixedEndpoint;
    final now = DateTime.now();
    if (_configuredEndpoint != null &&
        _configurationReadAt != null &&
        now.difference(_configurationReadAt!) < const Duration(hours: 6)) {
      return _configuredEndpoint!;
    }
    try {
      final response = await _client
          .get(
            Uri.parse(_configurationUrl),
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final value = jsonDecode(utf8.decode(response.bodyBytes));
        if (value is Map && value['enabled'] == true) {
          final candidate = Uri.tryParse('${value['endpoint'] ?? ''}');
          if (candidate != null && candidate.scheme == 'https') {
            _configuredEndpoint = candidate;
          }
        }
      }
    } catch (_) {
      // The public configuration is optional; retain the safe default.
    }
    _configurationReadAt = now;
    return _configuredEndpoint ?? Uri.parse(_defaultEndpoint);
  }

  static Future<void> _waitForRequestSlot() {
    final ready = Completer<void>();
    _requestGate = _requestGate.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequest);
      const minimumGap = Duration(milliseconds: 1100);
      if (elapsed < minimumGap) {
        await Future<void>.delayed(minimumGap - elapsed);
      }
      _lastRequest = DateTime.now();
      ready.complete();
    });
    return ready.future;
  }

  Future<List<PlaceSearchResult>> _searchDevice(
    String query,
    Future<List<Location>> Function(String) forward,
  ) async {
    final matches = await forward(query).timeout(const Duration(seconds: 10));
    final seen = <String>{};
    final candidates = matches
        .where(
          (point) =>
              CaptureSession.validCoordinates(
                point.latitude,
                point.longitude,
              ) &&
              seen.add(
                '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
              ),
        )
        .take(3);
    return Future.wait(
      candidates.map((point) async {
        var address = query;
        try {
          final places = await _reverse(
            point.latitude,
            point.longitude,
          ).timeout(const Duration(seconds: 4));
          if (places.isNotEmpty) {
            final p = places.first;
            final parts = <String>[];
            for (final part in [
              p.name,
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
              p.country,
            ]) {
              if (part == null || part.trim().isEmpty) continue;
              final trimmed = part.trim();
              if (!parts.any(
                (existing) =>
                    existing.toLowerCase().contains(trimmed.toLowerCase()),
              )) {
                parts.add(trimmed);
              }
            }
            if (parts.isNotEmpty) address = parts.join(', ');
          }
        } catch (_) {
          // A valid pin is still usable when its detailed address cannot be read.
        }
        return PlaceSearchResult(
          latitude: point.latitude,
          longitude: point.longitude,
          address: address,
        );
      }),
    );
  }

  void close() => _ownedClient?.close();
}
