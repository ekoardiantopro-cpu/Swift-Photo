import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/watermark_data.dart';
import '../models/camera_options.dart';
import '../models/template_customization.dart';
import 'photo_integrity_service.dart';

class PhotoProject {
  const PhotoProject({
    required this.photo,
    required this.source,
    required this.data,
    required this.ratio,
    required this.integrity,
    this.logo,
  });
  final File photo;
  final File source;
  final WatermarkData data;
  final PhotoRatio ratio;
  final PhotoIntegrityReport integrity;
  final File? logo;
}

/// Sidecars keep the clean source and capture settings for nondestructive edits.
class PhotoProjectService {
  Future<void> save(
    File photo,
    Uint8List source,
    WatermarkData data,
    PhotoRatio ratio, {
    Uint8List? logo,
    File? parentPhoto,
  }) async {
    final directory = await Directory(
      '${photo.path}.project',
    ).create(recursive: true);
    await File(
      '${directory.path}/source.image',
    ).writeAsBytes(source, flush: true);
    if (logo != null) {
      await File('${directory.path}/logo.png').writeAsBytes(logo, flush: true);
    }
    final file = File('${directory.path}/data.json.part');
    await file.writeAsString(
      jsonEncode({
        'version': 2,
        'customization': data.customization.toJson(),
        'capturedAt': data.capturedAt.toIso8601String(),
        'latitude': data.latitude,
        'longitude': data.longitude,
        'address': data.address,
        'layout': data.layout.name,
        'template': data.template.name,
        'enabled': data.enabled,
        'isManual': data.isManual,
        'isEdited': data.isEdited,
        'photoCode': data.photoCode,
        'ratio': ratio.name,
      }),
      flush: true,
    );
    final metadata = await file.rename('${directory.path}/data.json');
    await PhotoIntegrityService().write(
      photo: photo,
      source: File('${directory.path}/source.image'),
      metadata: metadata,
      data: data,
      parentPhoto: parentPhoto,
    );
  }

  Future<PhotoProject?> load(File photo) async {
    final directory = '${photo.path}.project';
    final metadata = File('$directory/data.json');
    final source = File('$directory/source.image');
    if (!await metadata.exists() || !await source.exists()) return null;
    final j = jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    final logo = File('$directory/logo.png');
    final integrity = await PhotoIntegrityService().verify(photo);
    return PhotoProject(
      photo: photo,
      source: source,
      integrity: integrity,
      logo: await logo.exists() ? logo : null,
      ratio: PhotoRatio.values.byName(j['ratio'] as String),
      data: WatermarkData(
        capturedAt: DateTime.parse(j['capturedAt'] as String),
        customization: TemplateCustomization.fromJson(j['customization']),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        address: j['address'] as String,
        layout: WatermarkLayout.values.byName(j['layout'] as String),
        template: MarkTemplate.values.byName(j['template'] as String),
        enabled: j['enabled'] as bool,
        isManual: j['isManual'] as bool,
        isEdited: j['isEdited'] == true,
        photoCode: j['photoCode'] as String,
      ),
    );
  }
}
