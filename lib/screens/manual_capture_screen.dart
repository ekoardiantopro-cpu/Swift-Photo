import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/capture_session.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';

class ManualCaptureScreen extends StatefulWidget {
  const ManualCaptureScreen({
    super.key,
    this.initial,
    this.initialLatitude,
    this.initialLongitude,
  });
  final CaptureSession? initial;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<ManualCaptureScreen> createState() => _ManualCaptureScreenState();
}

class _ManualCaptureScreenState extends State<ManualCaptureScreen> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  final _search = TextEditingController();
  final _placeSearch = PlaceSearchService();
  List<PlaceSearchResult> _results = [];
  String? _searchMessage;
  bool _searching = false;
  bool _findingLocation = false;
  int _searchEpoch = 0;
  int _pinIntent = 0;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _address;
  late LatLng _pin;
  late DateTime _time;
  bool _lookingUp = false;
  bool _mapUnavailable = false;
  int _lookup = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _pin = LatLng(
      initial?.latitude ?? widget.initialLatitude ?? -6.175392,
      initial?.longitude ?? widget.initialLongitude ?? 106.827153,
    );
    _time = initial?.manualTime ?? DateTime.now();
    _latitude = TextEditingController(text: _pin.latitude.toStringAsFixed(6));
    _longitude = TextEditingController(text: _pin.longitude.toStringAsFixed(6));
    _address = TextEditingController(text: initial?.address ?? '');
  }

  Future<void> _setPin(LatLng point, {String? address}) async {
    ++_pinIntent;
    final lookup = ++_lookup;
    setState(() {
      _pin = point;
      _latitude.text = point.latitude.toStringAsFixed(6);
      _longitude.text = point.longitude.toStringAsFixed(6);
      _address.text = address ?? '';
      _lookingUp = address == null;
    });
    if (address != null) return;
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(point.latitude, point.longitude)
          .timeout(const Duration(seconds: 5));
      if (!mounted || lookup != _lookup || _address.text.isNotEmpty) return;
      if (places.isNotEmpty) {
        final place = places.first;
        _address.text = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
      }
    } catch (_) {
      // Alamat tetap dapat diketik saat geocoding atau jaringan tidak tersedia.
    } finally {
      if (mounted && lookup == _lookup) setState(() => _lookingUp = false);
    }
  }

  Future<void> _searchPlaces() async {
    final query = _search.text.trim();
    final epoch = ++_searchEpoch;
    if (query.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searchMessage = 'Ketik nama tempat atau alamat minimal 2 karakter.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _results = [];
      _searchMessage = null;
    });
    try {
      final results = await _placeSearch.search(query);
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _results = results;
        _searchMessage = results.isEmpty
            ? 'Tempat tidak ditemukan. Coba alamat yang lebih lengkap.'
            : null;
      });
    } catch (_) {
      if (!mounted || epoch != _searchEpoch) return;
      setState(
        () => _searchMessage =
            'Pencarian belum tersedia. Periksa jaringan atau pilih pin pada peta.',
      );
    } finally {
      if (mounted && epoch == _searchEpoch) setState(() => _searching = false);
    }
  }

  void _showTypeAhead(String value) {
    ++_searchEpoch;
    final query = value.trim();
    setState(() {
      _results = _placeSearch.suggest(query);
      _searchMessage = query.length == 1
          ? 'Ketik minimal 2 karakter untuk melihat saran.'
          : null;
      _searching = false;
    });
  }

  Future<void> _selectPlace(PlaceSearchResult result) async {
    ++_searchEpoch;
    FocusScope.of(context).unfocus();
    setState(() {
      _results = [];
      _searching = false;
      _searchMessage = null;
    });
    _search.text = result.address;
    final point = LatLng(result.latitude, result.longitude);
    _map.move(point, 16);
    await _setPin(point, address: result.address);
  }

  Future<void> _useCurrentLocation() async {
    if (_findingLocation) return;
    FocusScope.of(context).unfocus();
    final intent = ++_pinIntent;
    ++_searchEpoch;
    setState(() {
      _findingLocation = true;
      _results = [];
      _searching = false;
      _searchMessage = null;
    });
    try {
      final location = await LocationService().read();
      if (!mounted || intent != _pinIntent) return;
      if (location.latitude == null || location.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${location.address}. Pin sebelumnya tetap digunakan.',
            ),
          ),
        );
        return;
      }
      final point = LatLng(location.latitude!, location.longitude!);
      _map.move(point, 16);
      await _setPin(point, address: location.address);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pin dipindahkan ke lokasi perangkat saat ini.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _findingLocation = false);
    }
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
  String? _validateNumber(String? text, double limit) {
    final value = _number(text ?? '');
    return value == null || !value.isFinite || value < -limit || value > limit
        ? 'Isi angka -$limit sampai $limit'
        : null;
  }

  Future<void> _applyCoordinates() async {
    final lat = _number(_latitude.text);
    final lng = _number(_longitude.text);
    if (lat == null ||
        lng == null ||
        !CaptureSession.validCoordinates(lat, lng)) {
      _form.currentState!.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    final point = LatLng(lat, lng);
    _map.move(point, 16);
    await _setPin(point);
  }

  Future<void> _chooseDate() async {
    FocusScope.of(context).unfocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) {
      setState(
        () => _time = DateTime(
          date.year,
          date.month,
          date.day,
          _time.hour,
          _time.minute,
          _time.second,
        ),
      );
    }
  }

  Future<void> _chooseTime() async {
    FocusScope.of(context).unfocus();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null && mounted) {
      setState(
        () => _time = DateTime(
          _time.year,
          _time.month,
          _time.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      CaptureSession.fake(
        time: _time,
        latitude: _number(_latitude.text)!,
        longitude: _number(_longitude.text)!,
        address: _address.text,
      ),
    );
  }

  @override
  void dispose() {
    ++_lookup;
    ++_searchEpoch;
    ++_pinIntent;
    _search.dispose();
    _placeSearch.close();
    _map.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatFullDate(_time);
    final time =
        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Atur mode Manual')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pin location',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ketuk peta untuk memilih titik. Data ini diisi manual.',
                style: TextStyle(color: Color(0xFF73777F), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('place-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchPlaces(),
                onChanged: _showTypeAhead,
                decoration: InputDecoration(
                  hintText: 'Cari tempat atau alamat',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(15),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('submit-place-search'),
                          tooltip: 'Cari lokasi',
                          onPressed: _searchPlaces,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                ),
              ),
              if (_searchMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _searchMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73777F),
                    ),
                  ),
                ),
              if (_results.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final result in _results)
                          ListTile(
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text(
                              result.title ?? result.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              result.title == null
                                  ? '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}'
                                  : result.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.north_west, size: 18),
                            onTap: () => _selectPlace(result),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_results.any(
                (result) => result.source == PlaceSearchSource.openStreetMap,
              ))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Hasil © OpenStreetMap contributors'),
                  ),
                ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 235,
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _pin,
                      initialZoom: 15,
                      onTap: (_, point) => _setPin(point),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.swiftphoto.swift_photo',
                        errorTileCallback: (_, _, _) {
                          if (mounted && !_mapUnavailable) {
                            setState(() => _mapUnavailable = true);
                          }
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin,
                            width: 48,
                            height: 56,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFE7A900),
                              size: 48,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/copyright',
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Material(
                            color: Colors.white,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(14),
                            child: IconButton(
                              key: const ValueKey('current-location'),
                              tooltip: 'Lokasi saat ini',
                              onPressed: _findingLocation
                                  ? null
                                  : _useCurrentLocation,
                              icon: _findingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_mapUnavailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Peta belum termuat. Anda tetap bisa mengisi koordinat dan alamat.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF73777F)),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('manual-latitude'),
                      controller: _latitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (text) => _validateNumber(text, 90),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('manual-longitude'),
                      controller: _longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (text) => _validateNumber(text, 180),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _applyCoordinates,
                  icon: const Icon(Icons.pin_drop_outlined, size: 18),
                  label: const Text('Terapkan koordinat'),
                ),
              ),
              TextFormField(
                key: const ValueKey('manual-address'),
                controller: _address,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat pada watermark',
                  hintText: 'Jalan, kecamatan, kota / kabupaten',
                  helperText: _lookingUp
                      ? 'Mencari alamat pin…'
                      : 'Alamat dapat Anda ketik atau perbaiki.',
                ),
                validator: (text) => text == null || text.trim().isEmpty
                    ? 'Isi alamat lokasi.'
                    : null,
              ),
              const SizedBox(height: 26),
              const Text(
                'Date & time',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('manual-date'),
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: const Text('Tanggal'),
                      subtitle: Text(date),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _chooseDate,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      key: const ValueKey('manual-time'),
                      leading: const Icon(Icons.schedule),
                      title: const Text('Waktu'),
                      subtitle: Text(time),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _chooseTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: FilledButton(
              key: const ValueKey('confirm-manual'),
              onPressed: _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Text('OK, buka kamera'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
