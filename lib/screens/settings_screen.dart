import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/camera_options.dart';
import '../services/settings_service.dart';
import '../widgets/cloud_sync_tile.dart';
import '../widgets/public_policy_link.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  CameraSettings? _settings;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _service.load();
      if (mounted) setState(() => _settings = value);
    } catch (_) {
      if (mounted) setState(() => _error = 'Pengaturan belum dapat dibaca.');
    }
  }

  Future<void> _save({PhotoQuality? quality}) async {
    setState(() => _saving = true);
    try {
      await _service.update(quality: quality);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan belum tersimpan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exitApp() async {
    if (_saving) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await SystemNavigator.pop();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tutup Swift Photo melalui pengalih aplikasi perangkat.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: _settings == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Kualitas foto',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Berlaku untuk foto berikutnya. Resolusi aktual mengikuti kemampuan kamera perangkat.',
                  style: TextStyle(color: Color(0xFF73777F)),
                ),
                const SizedBox(height: 20),
                for (final quality in PhotoQuality.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        color: _settings!.quality == quality
                            ? const Color(0xFFEAF5FF)
                            : const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        enabled: !_saving,
                        leading: Icon(
                          quality == PhotoQuality.hd
                              ? Icons.hd_outlined
                              : quality == PhotoQuality.low
                              ? Icons.photo_size_select_small_outlined
                              : Icons.photo_outlined,
                        ),
                        title: Text(quality.label),
                        subtitle: Text(quality.description),
                        trailing: Icon(
                          _settings!.quality == quality
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: _settings!.quality == quality
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        onTap: () => _save(quality: quality),
                      ),
                    ),
                  ),
                const Divider(height: 36),
                const CloudSyncTile(),
                const Divider(height: 36),
                const PublicPolicyLink(
                  label: 'Kebijakan privasi',
                  path: '/privacy',
                  icon: Icons.privacy_tip_outlined,
                ),
                const PublicPolicyLink(
                  label: 'Ketentuan penggunaan',
                  path: '/terms',
                  icon: Icons.description_outlined,
                ),
                const PublicPolicyLink(
                  label: 'Bantuan & hapus data',
                  path: '/support',
                  icon: Icons.help_outline_rounded,
                ),
                const Divider(height: 40),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Tentang aplikasi'),
                  subtitle: const Text('Versi, pengembang & kontak'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _saving
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _exitApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD43C49),
                    side: const BorderSide(color: Color(0xFFF0C4C8)),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar aplikasi'),
                ),
                if (defaultTargetPlatform == TargetPlatform.iOS)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Di iOS, tutup aplikasi melalui pengalih aplikasi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF73777F)),
                    ),
                  ),
              ],
            ),
    ),
  );
}
