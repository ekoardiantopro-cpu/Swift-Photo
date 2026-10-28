import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:image_picker/image_picker.dart';
import '../models/template_customization.dart';
import '../models/watermark_data.dart';
import '../services/watermark_renderer.dart';

class TemplateDesignResult {
  const TemplateDesignResult(this.customization, {this.logoBytes});
  final TemplateCustomization customization;
  final Uint8List? logoBytes;
}

class TemplateDesignerScreen extends StatefulWidget {
  const TemplateDesignerScreen({
    super.key,
    required this.data,
    this.logo,
    this.aspectRatio = .75,
  });
  final WatermarkData data;
  final ui.Image? logo;
  final double aspectRatio;
  @override
  State<TemplateDesignerScreen> createState() => _TemplateDesignerScreenState();
}

class _TemplateDesignerScreenState extends State<TemplateDesignerScreen> {
  late TemplateCustomization _config = widget.data.customization;
  ui.Image? _ownedLogo;
  Uint8List? _logoBytes;
  bool _picking = false;
  String _tool = 'Posisi';
  ui.Image? get _logo => _ownedLogo ?? widget.logo;
  Future<void> _changeLogo() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      late ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      final old = _ownedLogo;
      setState(() {
        _ownedLogo = image;
        _logoBytes = bytes;
        _config = _config.copyWith(showLogo: true);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo belum dapat dibuka. Coba gambar lain.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _update(TemplateCustomization value) => setState(() => _config = value);
  @override
  void dispose() {
    _ownedLogo?.dispose();
    super.dispose();
  }

  Widget _preview() => Center(
    child: AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final logo = _logo;
          final rect = _config.logoRect(
            size,
            logo == null ? 2.8 : logo.width / logo.height,
          );
          return ClipRect(
            child: Stack(
              key: const ValueKey('template-preview'),
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFB7C5CC),
                        Color(0xFF596F80),
                        Color(0xFF253C51),
                      ],
                    ),
                  ),
                ),
                CustomPaint(
                  painter: WatermarkPainter(
                    widget.data.copyWith(customization: _config, enabled: true),
                    logo: logo,
                    drawLogo: false,
                  ),
                ),
                if (_config.showLogo)
                  Positioned.fromRect(
                    rect: rect,
                    child: Semantics(
                      label:
                          'Logo. Geser untuk memindahkan, atau gunakan pengatur posisi di bawah.',
                      child: GestureDetector(
                        key: const ValueKey('draggable-logo'),
                        dragStartBehavior: DragStartBehavior.down,
                        onTap: logo == null
                            ? _changeLogo
                            : () => setState(() => _tool = 'Posisi'),
                        onPanUpdate: (details) {
                          final current = _config.logoRect(
                            size,
                            logo == null ? 2.8 : logo.width / logo.height,
                          );
                          final candidate = _config.copyWith(
                            logoX:
                                (current.left + details.delta.dx) / size.width,
                            logoY:
                                (current.top + details.delta.dy) / size.height,
                          );
                          final bounded = candidate.logoRect(
                            size,
                            logo == null ? 2.8 : logo.width / logo.height,
                          );
                          _update(
                            candidate.copyWith(
                              logoX: bounded.left / size.width,
                              logoY: bounded.top / size.height,
                            ),
                          );
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF57BDFF),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(
                              rect.shortestSide * _config.logoRadius,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              rect.shortestSide * _config.logoRadius,
                            ),
                            child: Opacity(
                              opacity: _config.logoOpacity,
                              child: logo == null
                                  ? const ColoredBox(
                                      color: Color(0x4470B9F5),
                                      child: Center(
                                        child: FittedBox(
                                          child: Padding(
                                            padding: EdgeInsets.all(12),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .add_photo_alternate_outlined,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Tambah logo',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : RawImage(image: logo, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Text(
                      'Geser logo ke posisi yang Anda inginkan',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF087EF0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        label: '${(value * 100).round()}%',
        onChanged: onChanged,
      ),
    ],
  );
  Widget _controls() => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Edit Template',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _picking ? null : _changeLogo,
              child: Text(_picking ? 'Membuka...' : 'Ganti logo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tool in ['Posisi', 'Ukuran', 'Alpha', 'Sudut'])
              ChoiceChip(
                label: Text(tool),
                selected: _tool == tool,
                onSelected: (_) => setState(() => _tool = tool),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Padding(
              key: ValueKey(_tool),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: switch (_tool) {
                'Ukuran' => _slider(
                  'Ukuran logo',
                  _config.logoWidth,
                  .08,
                  .65,
                  (value) => _update(_config.copyWith(logoWidth: value)),
                ),
                'Alpha' => _slider(
                  'Transparansi logo',
                  _config.logoOpacity,
                  .1,
                  1,
                  (value) => _update(_config.copyWith(logoOpacity: value)),
                ),
                'Sudut' => _slider(
                  'Sudut membulat',
                  _config.logoRadius,
                  0,
                  .5,
                  (value) => _update(_config.copyWith(logoRadius: value)),
                ),
                _ => Column(
                  children: [
                    _slider(
                      'Horizontal',
                      _config.logoX,
                      0,
                      1,
                      (value) => _update(_config.copyWith(logoX: value)),
                    ),
                    _slider(
                      'Vertikal',
                      _config.logoY,
                      0,
                      1,
                      (value) => _update(_config.copyWith(logoY: value)),
                    ),
                  ],
                ),
              },
            ),
          ),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Logo'),
          secondary: const Icon(Icons.image_outlined),
          value: _config.showLogo,
          onChanged: (v) => _update(_config.copyWith(showLogo: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Waktu & tanggal'),
          secondary: const Icon(Icons.schedule_rounded),
          value: _config.showTime,
          onChanged: (v) => _update(_config.copyWith(showTime: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Alamat'),
          secondary: const Icon(Icons.location_on_outlined),
          value: _config.showAddress,
          onChanged: (v) => _update(_config.copyWith(showAddress: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Koordinat'),
          secondary: const Icon(Icons.my_location_rounded),
          value: _config.showCoordinates,
          onChanged: (v) => _update(_config.copyWith(showCoordinates: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Photo Code'),
          secondary: const Icon(Icons.tag_rounded),
          value: _config.showCode,
          onChanged: (v) => _update(_config.copyWith(showCode: v)),
        ),
        TextButton.icon(
          onPressed: () => _update(const TemplateCustomization()),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reset tampilan template'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF263C50),
    appBar: AppBar(
      title: const Text('Preview'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF078EED),
            ),
            onPressed: _picking
                ? null
                : () => Navigator.pop(
                    context,
                    TemplateDesignResult(_config, logoBytes: _logoBytes),
                  ),
            child: const Text('Simpan'),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 700
            ? Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _preview(),
                    ),
                  ),
                  SizedBox(width: 360, child: _controls()),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 5, child: _preview()),
                  Expanded(flex: 5, child: _controls()),
                ],
              ),
      ),
    ),
  );
}
