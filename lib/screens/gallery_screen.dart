import 'dart:io';

import 'package:flutter/material.dart';

import '../services/local_media_service.dart';
import '../services/photo_integrity_service.dart';
import '../widgets/cloud_sync_tile.dart';
import 'photo_editor_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.editPhotos = false});
  final bool editPhotos;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<File>> _photos = LocalMediaService().listPhotos();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.editPhotos ? 'Edit Photo - Pilih foto' : 'Drive'),
    ),
    body: Column(
      children: [
        if (!widget.editPhotos)
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CloudSyncTile(),
          ),
        Expanded(
          child: FutureBuilder<List<File>>(
            future: _photos,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Penyimpanan internal gagal dibaca.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final photos = snapshot.data!;
              if (photos.isEmpty) {
                return const Center(
                  child: Text('Belum ada foto. Ambil foto pertama Anda.'),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photos.length,
                itemBuilder: (context, index) => Semantics(
                  label:
                      '${widget.editPhotos ? "Edit" : "Buka"} foto ${index + 1}',
                  button: true,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => widget.editPhotos
                              ? PhotoEditorScreen(file: photos[index])
                              : PhotoPreviewScreen(file: photos[index]),
                        ),
                      );
                      if (mounted && widget.editPhotos) {
                        final photos = LocalMediaService().listPhotos();
                        setState(() {
                          _photos = photos;
                        });
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        photos[index],
                        fit: BoxFit.cover,
                        cacheWidth: 360,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class PhotoPreviewScreen extends StatefulWidget {
  const PhotoPreviewScreen({super.key, required this.file});
  final File file;

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _saving = false;
  late final Future<PhotoIntegrityReport> _integrity = PhotoIntegrityService()
      .verify(widget.file);

  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    String message;
    try {
      await LocalMediaService().saveToGallery(widget.file);
      message = 'Salinan foto tersimpan di galeri perangkat.';
    } catch (error) {
      message = 'Galeri gagal: $error. Foto internal tetap tersimpan.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hasil watermark')),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.file(
                widget.file,
                errorBuilder: (_, _, _) => const Text('Foto gagal dibuka.'),
              ),
            ),
          ),
        ),
        FutureBuilder<PhotoIntegrityReport>(
          future: _integrity,
          builder: (context, snapshot) {
            final report = snapshot.data;
            if (report == null) return const SizedBox.shrink();
            final verified = report.state == PhotoIntegrityState.verified;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: verified
                    ? const Color(0xFFEAF7EF)
                    : const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    verified
                        ? Icons.verified_user_outlined
                        : Icons.gpp_maybe_outlined,
                    color: verified
                        ? const Color(0xFF177245)
                        : const Color(0xFF9D5B14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verified
                          ? 'Integritas lokal cocok · ${report.integrityId}'
                          : report.message ??
                                'Integritas belum dapat dipastikan.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveToGallery,
              icon: const Icon(Icons.save_alt),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan salinan ke galeri'),
            ),
          ),
        ),
      ],
    ),
  );
}
