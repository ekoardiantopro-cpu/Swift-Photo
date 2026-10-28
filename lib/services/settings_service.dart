import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/watermark_data.dart';
import '../models/camera_options.dart';
import '../models/template_customization.dart';

class CameraSettings {
  const CameraSettings({
    this.layout = WatermarkLayout.bottomLeft,
    this.logo,
    this.template = MarkTemplate.classic,
    this.enabled = true,
    this.cloudEnabled = false,
    this.quality = PhotoQuality.hd,
    this.customizations = const {},
  });
  final Map<MarkTemplate, TemplateCustomization> customizations;
  final PhotoQuality quality;
  final MarkTemplate template;
  final bool enabled;
  final bool cloudEnabled;
  final WatermarkLayout layout;
  final Uint8List? logo;
}

class SettingsService {
  SettingsService({this._directoryProvider});
  final Future<Directory> Function()? _directoryProvider;
  Future<void> removeLogo() async {
    final directory = await _directory();
    final logo = File('${directory.path}/company_logo.image');
    if (await logo.exists()) await logo.delete();
  }

  Future<Directory> _directory() async {
    if (_directoryProvider != null) return _directoryProvider();
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/settings').create(recursive: true);
  }

  Future<CameraSettings> load() async {
    final directory = await _directory();
    var layout = WatermarkLayout.bottomLeft;
    var template = MarkTemplate.classic;
    var enabled = true;
    var cloudEnabled = false;
    var quality = PhotoQuality.hd;
    final customizations = <MarkTemplate, TemplateCustomization>{};
    final settings = File('${directory.path}/camera.json');
    if (await settings.exists()) {
      try {
        final json =
            jsonDecode(await settings.readAsString()) as Map<String, dynamic>;
        template = MarkTemplate.values.firstWhere(
          (v) => v.name == json['template'],
          orElse: () => MarkTemplate.classic,
        );
        final configs = json['customizations'];
        if (configs is Map) {
          for (final t in MarkTemplate.values) {
            if (configs.containsKey(t.name)) {
              customizations[t] = TemplateCustomization.fromJson(
                configs[t.name],
              );
            }
          }
        }
        enabled = json['enabled'] != false;
        cloudEnabled = json['cloudEnabled'] == true;
        quality = PhotoQuality.values.firstWhere(
          (v) => v.name == json['quality'],
          orElse: () => PhotoQuality.hd,
        );
        layout = WatermarkLayout.values.firstWhere(
          (value) => value.name == json['layout'],
          orElse: () => WatermarkLayout.bottomLeft,
        );
      } on FormatException {
        // File pengaturan rusak tidak boleh menghalangi kamera.
      } on TypeError {
        // Gunakan pengaturan dasar jika format dari versi lama berbeda.
      }
    }
    final logo = File('${directory.path}/company_logo.image');
    return CameraSettings(
      layout: layout,
      template: template,
      enabled: enabled,
      cloudEnabled: cloudEnabled,
      quality: quality,
      customizations: customizations,
      logo: await logo.exists() ? await logo.readAsBytes() : null,
    );
  }

  Future<void> saveLayout(WatermarkLayout layout) => update(layout: layout);

  Future<void> update({
    WatermarkLayout? layout,
    MarkTemplate? template,
    bool? enabled,
    bool? cloudEnabled,
    PhotoQuality? quality,
    TemplateCustomization? customization,
  }) async {
    final previous = await load();
    final configs = {...previous.customizations};
    if (customization != null) {
      configs[template ?? previous.template] = customization;
    }
    final directory = await _directory();
    final temporary = File('${directory.path}/camera.json.part');
    await temporary.writeAsString(
      jsonEncode({
        'layout': (layout ?? previous.layout).name,
        'template': (template ?? previous.template).name,
        'enabled': enabled ?? previous.enabled,
        'cloudEnabled': cloudEnabled ?? previous.cloudEnabled,
        'quality': (quality ?? previous.quality).name,
        'customizations': configs.map(
          (key, value) => MapEntry(key.name, value.toJson()),
        ),
      }),
      flush: true,
    );
    await temporary.rename('${directory.path}/camera.json');
  }

  Future<void> saveLogo(Uint8List bytes) async {
    final directory = await _directory();
    final temporary = File('${directory.path}/company_logo.image.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename('${directory.path}/company_logo.image');
  }
}
