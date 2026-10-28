import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_data.dart';
import '../services/watermark_renderer.dart';

enum WatermarkEditAction { mode, logo, removeLogo, layout, template }

class WatermarkEditChoice {
  const WatermarkEditChoice(
    this.action, {
    this.layout,
    this.template,
    this.enabled,
  });
  final WatermarkEditAction action;
  final WatermarkLayout? layout;
  final MarkTemplate? template;
  final bool? enabled;
}

class EditWatermarkSheet extends StatefulWidget {
  const EditWatermarkSheet({
    super.key,
    required this.layout,
    required this.hasLogo,
    required this.template,
    required this.enabled,
    this.logo,
  });
  final WatermarkLayout layout;
  final bool hasLogo;
  final MarkTemplate template;
  final bool enabled;
  final ui.Image? logo;
  @override
  State<EditWatermarkSheet> createState() => _EditWatermarkSheetState();
}

class _EditWatermarkSheetState extends State<EditWatermarkSheet> {
  String _query = '';
  void _select(MarkTemplate? template) => Navigator.pop(
    context,
    WatermarkEditChoice(
      WatermarkEditAction.template,
      template: template,
      enabled: template != null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final templates = MarkTemplate.values
        .where((t) => t.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Nonaktifkan semua template',
                      onPressed: () => _select(null),
                      icon: Icon(
                        Icons.block_rounded,
                        color: widget.enabled ? null : Colors.blue,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Templates',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari template',
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          const WatermarkEditChoice(WatermarkEditAction.logo),
                        ),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          widget.hasLogo ? 'Ganti logo' : 'Tambah logo',
                        ),
                      ),
                    ),
                    if (widget.hasLogo)
                      IconButton(
                        tooltip: 'Hapus logo',
                        onPressed: () => Navigator.pop(
                          context,
                          const WatermarkEditChoice(
                            WatermarkEditAction.removeLogo,
                          ),
                        ),
                        icon: const Icon(Icons.hide_image_outlined),
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const WatermarkEditChoice(WatermarkEditAction.mode),
                      ),
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Data'),
                    ),
                    PopupMenuButton<WatermarkLayout>(
                      tooltip: 'Posisi watermark',
                      icon: const Icon(Icons.align_horizontal_left_rounded),
                      onSelected: (v) => Navigator.pop(
                        context,
                        WatermarkEditChoice(
                          WatermarkEditAction.layout,
                          layout: v,
                        ),
                      ),
                      itemBuilder: (_) => [
                        for (final v in WatermarkLayout.values)
                          PopupMenuItem(value: v, child: Text(v.label)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.enabled)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Tanpa watermark',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.65,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final selected =
                        widget.enabled && widget.template == template;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: template.label,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _select(template),
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF159BF3)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ColoredBox(
                                    color: const Color(0xFF818891),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CustomPaint(
                                          painter: WatermarkPainter(
                                            WatermarkData(
                                              capturedAt: DateTime(
                                                2026,
                                                10,
                                                25,
                                                9,
                                                30,
                                              ),
                                              address: 'Jalan Merdeka, Jakarta',
                                              latitude: -6.175392,
                                              longitude: 106.827153,
                                              template: template,
                                              photoCode: '7KWM9PXRTN6MTC',
                                            ),
                                            logo: widget.logo,
                                            thumbnail: true,
                                          ),
                                        ),
                                        if (selected)
                                          const Positioned(
                                            right: 5,
                                            top: 5,
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF159BF3),
                                              size: 20,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              template.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
