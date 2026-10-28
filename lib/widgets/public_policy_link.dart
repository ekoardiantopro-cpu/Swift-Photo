import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicPolicyLink extends StatelessWidget {
  const PublicPolicyLink({
    super.key,
    required this.label,
    required this.path,
    this.icon = Icons.open_in_new_rounded,
    this.subtitle,
  });
  final String label;
  final String path;
  final IconData icon;
  final String? subtitle;

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.https('swift-photo.web.app', path),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Keep the settings screen usable when no browser is available.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Halaman belum dapat dibuka. Coba lagi saat browser dan koneksi tersedia.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
    onTap: () => _open(context),
  );
}
