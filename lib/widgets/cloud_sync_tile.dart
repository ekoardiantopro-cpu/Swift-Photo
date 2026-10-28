import 'package:flutter/material.dart';
import '../screens/cloud_sync_screen.dart';

class CloudSyncTile extends StatelessWidget {
  const CloudSyncTile({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.add_to_drive_rounded, color: Color(0xFF078EED)),
    title: const Text('Sync Google Drive'),
    subtitle: const Text('Login Google dan pilih folder tujuan'),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CloudSyncScreen())),
  );
}
