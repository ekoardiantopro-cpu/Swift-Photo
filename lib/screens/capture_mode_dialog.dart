import 'package:flutter/material.dart';
import '../models/capture_session.dart';

Future<CaptureMode?> showCaptureModeDialog(BuildContext context) =>
    showDialog<CaptureMode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 32),
                const SizedBox(height: 20),
                const Text(
                  'Pilih mode kamera',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tentukan data yang akan tampil pada foto.',
                  style: TextStyle(color: Color(0xFF73777F), height: 1.5),
                ),
                const SizedBox(height: 24),
                _ModeCard(
                  mode: CaptureMode.real,
                  title: 'Live',
                  subtitle: 'GPS dan waktu dibaca langsung dari perangkat',
                  icon: Icons.my_location,
                  color: const Color(0xFFEBF6EF),
                ),
                const SizedBox(height: 12),
                _ModeCard(
                  mode: CaptureMode.fake,
                  title: 'Manual',
                  subtitle: 'Atur pin lokasi, tanggal, dan waktu sendiri',
                  icon: Icons.edit_location_alt_outlined,
                  color: const Color(0xFFFFF6D6),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final CaptureMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: ValueKey('choose-${mode.name}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).pop(mode),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 27),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 19),
          ],
        ),
      ),
    ),
  );
}
