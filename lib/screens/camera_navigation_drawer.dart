import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/swift_icon.dart';

enum CameraDestination { drive, templates, edit, settings }

class CameraNavigationDrawer extends StatelessWidget {
  const CameraNavigationDrawer({
    super.key,
    required this.onSelected,
    required this.onClose,
    required this.mode,
  });
  final ValueChanged<CameraDestination> onSelected;
  final VoidCallback onClose;
  final String mode;

  @override
  Widget build(BuildContext context) => Drawer(
    width: math.min(MediaQuery.sizeOf(context).width * 0.85, 340),
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
    ),
    child: SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8F8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.asset(
                        'assets/branding/swift_photo.png',
                        width: 38,
                        height: 38,
                        semanticLabel: 'Swift Photo',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Tutup menu',
                      onPressed: onClose,
                      icon: const SwiftIcon(SwiftGlyph.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Swift Photo',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dokumentasi di setiap langkah.',
                  style: TextStyle(color: Color(0xFF73777F), fontSize: 13),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Mode $mode',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 24, endIndent: 24),
          const SizedBox(height: 16),
          _DestinationTile(
            icon: SwiftGlyph.folder,
            title: 'Drive',
            subtitle: 'Foto dan dokumentasi tersimpan',
            onTap: () => onSelected(CameraDestination.drive),
          ),
          _DestinationTile(
            icon: SwiftGlyph.edit,
            title: 'Edit Photo',
            subtitle: 'Ubah watermark pada foto tersimpan',
            onTap: () => onSelected(CameraDestination.edit),
          ),
          _DestinationTile(
            icon: SwiftGlyph.ratio,
            title: 'Template',
            subtitle: 'Pilih watermark dan logo kamera',
            onTap: () => onSelected(CameraDestination.templates),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Pengaturan'),
              subtitle: const Text('Kualitas foto dan sinkronisasi cloud'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelected(CameraDestination.settings),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SWIFT PHOTO',
              style: TextStyle(
                color: Color(0xFF9CA1AA),
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final SwiftGlyph icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SwiftIcon(icon, color: const Color(0xFF343A42)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF73777F)),
      ),
      trailing: const SwiftIcon(SwiftGlyph.chevronRight, size: 18),
      onTap: onTap,
    ),
  );
}
