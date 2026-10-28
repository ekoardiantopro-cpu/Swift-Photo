import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/cloud_store.dart';
import '../services/cloud_sync_service.dart';
import '../services/drive_api.dart';
import '../widgets/public_policy_link.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});
  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _sync = CloudSyncService();
  CloudConfig? _config;
  ({int pending, int uploading, int synced, int blocked, String? error})?
  _summary;
  List<CloudJob> _jobs = const [];
  String? _error;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_busy) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final c = await _sync.store.config();
      final summary = await _sync.store.summary();
      final jobs = await _sync.store.jobs();
      if (mounted) {
        setState(() {
          _config = c;
          _summary = summary;
          _jobs = jobs;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Pengaturan cloud belum dapat dibaca. Buka ulang halaman ini.',
        );
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(
          () => _error =
              'Login Google belum berhasil. Periksa koneksi, persetujuan akun, package name, dan SHA-1 build Android.',
        );
      }
    } on DriveApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Koneksi belum berhasil. Periksa internet dan coba lagi.',
        );
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _run(() async {
    final account = await _sync.auth.connect();
    await _sync.store.connect(account.id, account.email);
    await _sync.store.retry();
    await _refresh();
    if (mounted) await _chooseFolder();
  });

  Future<void> _chooseFolder() async {
    final c = await _sync.store.config();
    if (!mounted || !c.connected) return;
    final folder = await Navigator.of(context).push<DriveFolder>(
      MaterialPageRoute(builder: (_) => DriveFolderScreen(config: c)),
    );
    if (folder == null) return;
    await _sync.store.target(folder.id, folder.name);
    await _sync.schedule();
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sync Google Drive')),
        body: c == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.add_to_drive_rounded,
                          size: 40,
                          color: Color(0xFF078EED),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Foto aman, kerja tetap lancar',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hubungkan akun Google langsung dari Swift Photo. Tidak perlu memasang aplikasi Google Drive.',
                        ),
                        if (c?.connected == true) ...[
                          const SizedBox(height: 16),
                          Text(
                            c!.email!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const PublicPolicyLink(
                    label: 'Bagaimana data Anda digunakan?',
                    subtitle:
                        'Email mengenali akun tujuan. Foto yang disinkronkan dikirim langsung ke Google Drive Anda.',
                    path: '/privacy',
                    icon: Icons.privacy_tip_outlined,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      c?.connected == true
                          ? 'Hubungkan ulang / ganti akun Google'
                          : 'Login dengan Google',
                    ),
                  ),
                  if (c?.connected == true) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.folder_open_rounded),
                      title: const Text('Folder tujuan'),
                      subtitle: Text(c!.folderName ?? 'Belum dipilih'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _busy ? null : () => _run(_chooseFolder),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sync foto baru otomatis'),
                      subtitle: const Text(
                        'Foto disimpan lokal dahulu. Antrean dicoba lagi saat koneksi tersedia.',
                      ),
                      value: c.enabled,
                      onChanged: _busy
                          ? null
                          : (value) => _run(() async {
                              if (!value) {
                                await _sync.pause();
                                return;
                              }
                              if (c.folderId == null) {
                                await _chooseFolder();
                                return;
                              }
                              await _sync.store.setEnabled(true);
                              await _sync.schedule();
                            }),
                    ),
                    const Text(
                      'Mengganti folder berlaku untuk foto baru. Antrean lama tetap menggunakan folder sebelumnya.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF687588)),
                    ),
                    const Divider(height: 32),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${_summary?.pending ?? 0} antrean')),
                        if ((_summary?.uploading ?? 0) > 0)
                          Chip(
                            avatar: const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: Text(
                              '${_summary?.uploading ?? 0} mengunggah',
                            ),
                          ),
                        Chip(
                          label: Text('${_summary?.synced ?? 0} tersinkron'),
                        ),
                        if ((_summary?.blocked ?? 0) > 0)
                          Chip(
                            label: Text('${_summary!.blocked} perlu tindakan'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy || !c.enabled
                          ? null
                          : () => _run(() async {
                              await _sync.store.retry();
                              await _sync.recover(includeOlderPhotos: true);
                              unawaited(
                                _sync
                                    .drain()
                                    .then((_) => _refresh())
                                    .catchError((Object _) => _refresh()),
                              );
                            }),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sync foto lokal sekarang'),
                    ),
                    const Text(
                      'Tombol ini juga memasukkan foto lama yang tersimpan di Swift Photo ke folder tujuan.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF687588)),
                    ),
                    if (_summary?.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _summary!.error!,
                          style: const TextStyle(color: Color(0xFF9D5B14)),
                        ),
                      ),
                    if (_jobs.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Aktivitas sync',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final job in _jobs)
                        _CloudJobTile(
                          job: job,
                          busy: _busy,
                          onRetry: () => _run(() async {
                            await _sync.store.retryJob(job.id);
                            await _sync.schedule();
                            unawaited(
                              _sync
                                  .drain()
                                  .then((_) => _refresh())
                                  .catchError((Object _) => _refresh()),
                            );
                          }),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await _sync.pause();
                              await _sync.auth.signOut();
                              await _sync.store.disconnect();
                            }),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Putuskan akun'),
                    ),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFC23343)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sync bersifat opsional. Saat dimatikan, foto tetap tersimpan lokal. Waktu unggah latar belakang mengikuti koneksi dan pengaturan baterai perangkat.',
                    style: TextStyle(color: Color(0xFF687588)),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CloudJobTile extends StatelessWidget {
  const _CloudJobTile({
    required this.job,
    required this.busy,
    required this.onRetry,
  });

  final CloudJob job;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (job.status) {
      CloudJobStatus.pending => (
        'Menunggu jaringan',
        Icons.schedule_rounded,
        const Color(0xFF8A6116),
      ),
      CloudJobStatus.uploading => (
        'Sedang mengunggah',
        Icons.cloud_upload_outlined,
        const Color(0xFF087EF0),
      ),
      CloudJobStatus.synced => (
        'Tersinkron',
        Icons.cloud_done_outlined,
        const Color(0xFF177245),
      ),
      CloudJobStatus.blocked => (
        'Perlu tindakan',
        Icons.error_outline_rounded,
        const Color(0xFFB3261E),
      ),
    };
    final retryable =
        job.status == CloudJobStatus.blocked ||
        (job.status == CloudJobStatus.pending && job.error != null);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(job.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.attempts > 0 ? '$label · percobaan ${job.attempts}' : label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (job.error != null)
              Text(job.error!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: job.error != null,
        trailing: retryable
            ? IconButton(
                tooltip: 'Coba unggah lagi',
                onPressed: busy ? null : onRetry,
                icon: const Icon(Icons.refresh_rounded),
              )
            : null,
      ),
    );
  }
}

class DriveFolderScreen extends StatefulWidget {
  const DriveFolderScreen({super.key, required this.config});
  final CloudConfig config;
  @override
  State<DriveFolderScreen> createState() => _DriveFolderScreenState();
}

class _DriveFolderScreenState extends State<DriveFolderScreen> {
  final _trail = <DriveFolder>[const DriveFolder('root', 'My Drive')];
  late final _api = CloudSyncService().api(widget.config);
  List<DriveFolder> _folders = [];
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await _api.folders(_trail.last.id);
      if (mounted) setState(() => _folders = folders);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is DriveApiException
              ? e.toString()
              : 'Folder belum dapat dibaca. Periksa koneksi atau hubungkan ulang akun.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(
        initialName: _trail.length == 1 ? 'Swift Photo' : 'Folder baru',
      ),
    );
    if (!mounted || name == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folder = await _api.createFolder(_trail.last.id, name);
      if (!mounted) return;
      _trail.add(folder);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is DriveApiException
              ? e.toString()
              : 'Folder belum berhasil dibuat. Muat ulang sebelum mencoba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pilih folder Google Drive'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            widget.config.email ?? '',
            style: const TextStyle(color: Color(0xFF687588)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Hanya folder yang diizinkan untuk Swift Photo ditampilkan. Buat folder baru di Drive untuk mulai menyimpan foto.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              for (var index = 0; index < _trail.length; index++)
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _trail.removeRange(index + 1, _trail.length);
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(_trail[index].name),
                ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _folders.isEmpty && !_loading
              ? const Center(
                  child: Text('Belum ada folder. Ketuk Buat folder.'),
                )
              : ListView.builder(
                  itemCount: _folders.length,
                  itemBuilder: (context, i) => ListTile(
                    enabled: !_loading,
                    leading: const Icon(
                      Icons.folder_rounded,
                      color: Color(0xFF078EED),
                    ),
                    title: Text(_folders[i].name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      _trail.add(_folders[i]);
                      _load();
                    },
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Buat folder'),
                ),
                FilledButton(
                  onPressed: _loading || _error != null || _trail.length == 1
                      ? null
                      : () => Navigator.pop(context, _trail.last),
                  child: const Text('Gunakan folder ini'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.initialName});
  final String initialName;
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Buat folder Drive'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Nama folder'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          final name = _controller.text.trim();
          if (name.isNotEmpty) Navigator.pop(context, name);
        },
        child: const Text('Buat'),
      ),
    ],
  );
}
