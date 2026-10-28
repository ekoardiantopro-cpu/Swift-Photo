import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_identity.dart';
import '../widgets/public_policy_link.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final _package = PackageInfo.fromPlatform();

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label disalin.')));
  }

  Future<void> _openContact(Uri uri, String fallback) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Emulators and some devices have no mail client or dialer configured.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fallback)));
  }

  Widget _contact({
    required IconData icon,
    required String label,
    required String value,
    required String action,
    required VoidCallback onOpen,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 14),
          child: Icon(icon, color: const Color(0xFF078EED)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(action),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Salin ${label.toLowerCase()}',
          onPressed: () => _copy(value, label),
          icon: const Icon(Icons.copy_outlined, size: 20),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang aplikasi')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/branding/swift_photo.png',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
                semanticLabel: 'Logo Swift Photo',
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            AppIdentity.name,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            AppIdentity.tagline,
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF687588)),
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _package,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? snapshot.hasError
                        ? 'Versi belum dapat dibaca'
                        : 'Membaca versi aplikasi...'
                  : 'Versi ${info.version}${info.buildNumber.isEmpty ? '' : ' (build ${info.buildNumber})'}';
              return Column(
                children: [
                  Text(
                    version,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Versi pengembangan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF687588)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FD),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF078EED),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengembang', style: TextStyle(fontSize: 12)),
                          SizedBox(height: 5),
                          Text(
                            AppIdentity.developer,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                _contact(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: AppIdentity.email,
                  action: 'Buka email',
                  onOpen: () => _openContact(
                    Uri(scheme: 'mailto', path: AppIdentity.email),
                    'Aplikasi email belum tersedia. Gunakan tombol salin email.',
                  ),
                ),
                const Divider(height: 1),
                _contact(
                  icon: Icons.phone_outlined,
                  label: 'Nomor telepon',
                  value: AppIdentity.phone,
                  action: 'Buka telepon',
                  onOpen: () => _openContact(
                    Uri(scheme: 'tel', path: AppIdentity.internationalPhone),
                    'Aplikasi telepon belum tersedia. Gunakan tombol salin nomor.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const PublicPolicyLink(
            label: 'Website Swift Photo',
            subtitle: 'swift-photo.web.app',
            path: '/',
            icon: Icons.language_rounded,
          ),
          TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppIdentity.name,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Lisensi sumber terbuka'),
          ),
        ],
      ),
    ),
  );
}
