import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_data.dart';
import '../models/watermark_regions.dart';
import '../services/photo_project_service.dart';
import '../services/local_media_service.dart';
import '../services/watermark_renderer.dart';
import '../services/photo_integrity_service.dart';

enum _Field { date, time, location, coordinates, code }

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.file});
  final File file;
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  PhotoProject? _project;
  ui.Image? _source;
  ui.Image? _logo;
  String? _error;
  bool _saving = false;
  bool _dirty = false;
  late DateTime _date;
  late String _address;
  late String _code;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<ui.Image> _decode(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _load() async {
    ui.Image? source;
    ui.Image? logo;
    try {
      final project = await PhotoProjectService().load(widget.file);
      if (project == null) {
        if (mounted) {
          setState(
            () => _error =
                'Foto ini belum memiliki foto asli dan data watermark terpisah. Watermark lama sudah menyatu dengan gambar. Ambil foto baru untuk menggunakan Edit Photo.',
          );
        }
        return;
      }
      source = await _decode(project.source);
      if (project.logo != null) logo = await _decode(project.logo!);
      if (!mounted) {
        source.dispose();
        logo?.dispose();
        return;
      }
      setState(() {
        _project = project;
        _source = source;
        _logo = logo;
        _date = project.data.capturedAt;
        _address = project.data.address;
        _code = project.data.photoCode;
        _latitude = project.data.latitude;
        _longitude = project.data.longitude;
      });
    } catch (_) {
      source?.dispose();
      logo?.dispose();
      if (mounted) {
        setState(
          () => _error =
              'Data edit foto tidak dapat dibaca. Foto tersimpan tetap aman.',
        );
      }
    }
  }

  WatermarkData get _data {
    final original = _project!.data;
    return WatermarkData(
      capturedAt: _date,
      address: _address,
      latitude: _latitude,
      longitude: _longitude,
      photoCode: _code,
      layout: original.layout,
      customization: original.customization,
      template: original.template,
      enabled: original.enabled,
      isManual: original.isManual,
      isEdited: _dirty || original.isEdited,
    );
  }

  Future<void> _edit(_Field field) async {
    if (_saving) return;
    if (field == _Field.date) {
      final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200, 12, 31),
      );
      if (value != null && mounted) {
        setState(() {
          _date = DateTime(
            value.year,
            value.month,
            value.day,
            _date.hour,
            _date.minute,
            _date.second,
          );
          _dirty = true;
        });
      }
      return;
    }
    if (field == _Field.time) {
      final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_date),
      );
      if (value != null && mounted) {
        setState(() {
          _date = DateTime(
            _date.year,
            _date.month,
            _date.day,
            value.hour,
            value.minute,
            _date.second,
          );
          _dirty = true;
        });
      }
      return;
    }
    final controller = TextEditingController(
      text: field == _Field.location
          ? _address
          : field == _Field.code
          ? _code
          : '${_latitude ?? ""}, ${_longitude ?? ""}',
    );
    final title = field == _Field.location
        ? 'Lokasi / alamat'
        : field == _Field.code
        ? 'Photo Code'
        : 'Koordinat GPS';
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: field == _Field.location ? 3 : 1,
            maxLength: field == _Field.code
                ? 14
                : field == _Field.location
                ? 240
                : 60,
            textCapitalization: field == _Field.code
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            decoration: InputDecoration(
              helperText: field == _Field.coordinates
                  ? 'Latitude, longitude. Contoh: -6.175392, 106.827153'
                  : null,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Isi data terlebih dahulu';
              }
              if (field == _Field.code &&
                  !RegExp(
                    r'^[A-Z0-9]{14}$',
                  ).hasMatch(value.trim().toUpperCase())) {
                return 'Gunakan 14 huruf kapital / angka';
              }
              if (field == _Field.coordinates) {
                final parts = value.split(',');
                final lat = parts.length == 2
                    ? double.tryParse(parts[0].trim())
                    : null;
                final lng = parts.length == 2
                    ? double.tryParse(parts[1].trim())
                    : null;
                if (lat == null ||
                    lng == null ||
                    !lat.isFinite ||
                    !lng.isFinite ||
                    lat.abs() > 90 ||
                    lng.abs() > 180) {
                  return 'Koordinat tidak valid';
                }
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
    // Route transition can still reference the controller after the dialog closes.
    if (value != null && mounted) {
      setState(() {
        if (field == _Field.location) _address = value;
        if (field == _Field.code) _code = value.toUpperCase();
        if (field == _Field.coordinates) {
          final parts = value.split(',');
          _latitude = double.parse(parts[0].trim());
          _longitude = double.parse(parts[1].trim());
        }
        _dirty = true;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<void> _chooseDateOrTime() async {
    final field = await showModalBottomSheet<_Field>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Ubah tanggal'),
              onTap: () => Navigator.pop(context, _Field.date),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Ubah jam'),
              onTap: () => Navigator.pop(context, _Field.time),
            ),
          ],
        ),
      ),
    );
    if (field != null && mounted) await _edit(field);
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      final project = _project!;
      final source = await project.source.readAsBytes();
      final output = await WatermarkRenderer().render(
        source,
        _data,
        _logo,
        ratio: project.ratio,
      );
      final saved = await LocalMediaService().saveInternal(
        output,
        editedFrom: project.photo,
      );
      var projectSaved = true;
      try {
        await PhotoProjectService().save(
          saved,
          source,
          _data,
          project.ratio,
          logo: await project.logo?.readAsBytes(),
          parentPhoto: project.photo,
        );
      } catch (_) {
        projectSaved = false;
      }
      var gallerySaved = true;
      try {
        await LocalMediaService().saveToGallery(saved);
      } catch (_) {
        gallerySaved = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !projectSaved
                ? 'Salinan tersimpan lokal; data edit ulang belum berhasil disimpan.'
                : gallerySaved
                ? 'Salinan hasil edit tersimpan di Drive dan galeri.'
                : 'Salinan tersimpan di Drive. Salin ke galeri melalui menu Drive.',
          ),
        ),
      );
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hasil edit belum berhasil disimpan. Silakan coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _source?.dispose();
    _logo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit Photo'),
        actions: [
          TextButton(
            onPressed: _dirty && !_saving ? _save : null,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan salinan'),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _project == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    _data.enabled
                        ? 'Ketuk tanggal, jam, lokasi, atau kode pada foto. Hasil edit disimpan sebagai salinan baru; status edit hanya tersimpan di metadata.'
                        : 'Foto ini diambil tanpa watermark. Aktifkan watermark untuk mengedit dan menampilkannya.',
                    style: const TextStyle(
                      color: Color(0xFF68717C),
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!_data.enabled)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            final p = _project!;
                            setState(() {
                              _project = PhotoProject(
                                photo: p.photo,
                                source: p.source,
                                logo: p.logo,
                                ratio: p.ratio,
                                integrity: p.integrity,
                                data: WatermarkData(
                                  capturedAt: _date,
                                  layout: p.data.layout,
                                  template: p.data.template,
                                  customization: p.data.customization,
                                  isManual: p.data.isManual,
                                ),
                              );
                              _dirty = true;
                            });
                          },
                    child: const Text('Aktifkan watermark'),
                  ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _project!.ratio
                          .cropBounds(_source!.width, _source!.height)
                          .size
                          .aspectRatio,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.biggest;
                          final h = size.height / size.width * 1000;
                          final regions = WatermarkRegions.forData(_data, h)
                            ..removeWhere(
                              (field, _) => switch (field) {
                                WatermarkField.dateTime ||
                                WatermarkField.date ||
                                WatermarkField.time =>
                                  !_data.customization.showTime,
                                WatermarkField.location =>
                                  !_data.customization.showAddress,
                                WatermarkField.coordinates =>
                                  !_data.customization.showCoordinates,
                                WatermarkField.code =>
                                  !_data.customization.showCode,
                              },
                            );
                          String label(WatermarkField field) => switch (field) {
                            WatermarkField.dateTime => 'Edit tanggal atau jam',
                            WatermarkField.date => 'Edit tanggal',
                            WatermarkField.time => 'Edit jam',
                            WatermarkField.location => 'Edit lokasi',
                            WatermarkField.coordinates => 'Edit koordinat',
                            WatermarkField.code => 'Edit Photo Code',
                          };
                          void editField(WatermarkField field) {
                            if (field == WatermarkField.dateTime) {
                              _chooseDateOrTime();
                              return;
                            }
                            _edit(switch (field) {
                              WatermarkField.date => _Field.date,
                              WatermarkField.time => _Field.time,
                              WatermarkField.location => _Field.location,
                              WatermarkField.coordinates => _Field.coordinates,
                              WatermarkField.code => _Field.code,
                              WatermarkField.dateTime => _Field.date,
                            });
                          }

                          Widget target(
                            Rect rect,
                            String label,
                            VoidCallback onTap,
                          ) => Positioned.fromRect(
                            rect: Rect.fromLTRB(
                              rect.left * size.width / 1000,
                              rect.top * size.width / 1000,
                              rect.right * size.width / 1000,
                              rect.bottom * size.width / 1000,
                            ),
                            child: Semantics(
                              button: true,
                              label: label,
                              child: Tooltip(
                                message: label,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _saving ? null : onTap,
                                    borderRadius: BorderRadius.circular(4),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0x8837B7FF),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _EditorPainter(
                                  _source!,
                                  _project!,
                                  _data,
                                  _logo,
                                ),
                              ),
                              for (final region in regions.entries)
                                target(
                                  region.value,
                                  label(region.key),
                                  () => editField(region.key),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                _IntegrityNotice(report: _project!.integrity),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final entry in const {
                          _Field.date: 'Tanggal',
                          _Field.time: 'Jam',
                          _Field.location: 'Lokasi',
                          _Field.coordinates: 'GPS',
                          _Field.code: 'Photo Code',
                        }.entries)
                          ActionChip(
                            label: Text(entry.value),
                            onPressed: _saving || !_data.enabled
                                ? null
                                : () => _edit(entry.key),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _IntegrityNotice extends StatelessWidget {
  const _IntegrityNotice({required this.report});

  final PhotoIntegrityReport report;

  @override
  Widget build(BuildContext context) {
    final verified = report.state == PhotoIntegrityState.verified;
    final missing = report.state == PhotoIntegrityState.missing;
    final color = verified
        ? const Color(0xFF177245)
        : missing
        ? const Color(0xFF68717C)
        : const Color(0xFFB3261E);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            verified ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              verified
                  ? 'Integritas lokal cocok · ${report.integrityId}'
                  : report.message ?? 'Integritas belum dapat dipastikan.',
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter(this.source, this.project, this.data, this.logo);
  final ui.Image source;
  final PhotoProject project;
  final WatermarkData data;
  final ui.Image? logo;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      source,
      project.ratio.cropBounds(source.width, source.height),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
    WatermarkPainter(data, logo: logo).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.source != source;
}
