import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/capture_session.dart';
import '../models/camera_options.dart';
import '../models/watermark_data.dart';
import '../services/async_operation_queue.dart';
import '../services/local_media_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/watermark_renderer.dart';
import 'capture_mode_dialog.dart';
import 'edit_watermark_sheet.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';
import 'template_designer_screen.dart';
import '../models/template_customization.dart';
import '../services/photo_project_service.dart';
import 'manual_capture_screen.dart';
import 'camera_navigation_drawer.dart';
import 'viewfinder_controls.dart';
import '../widgets/swift_icon.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final _storage = LocalMediaService();
  final _renderer = WatermarkRenderer();
  final _settings = SettingsService();
  final _cameraOperations = AsyncOperationQueue();
  final _scaffold = GlobalKey<ScaffoldState>();
  final _zoomRanges = <String, CameraZoomRange>{};
  List<CameraDescription> _cameras = [];
  CameraLensDirection _facing = CameraLensDirection.back;
  PhotoQuality _quality = PhotoQuality.hd;
  PhotoRatio _ratio = PhotoRatio.portrait;
  FlashMode _flash = FlashMode.off;
  double _zoom = 1;
  bool _useUltraWide = false;
  bool _flashAvailable = true;
  bool _controlBusy = false;
  bool _drawerOpen = false;
  CameraDestination? _pendingDrawerAction;
  CameraController? _camera;
  Timer? _clock;
  Timer? _gpsTimer;
  ui.Image? _logo;
  CaptureSession? _session;
  CaptureSession? _lastManual;
  LocationSnapshot _location = const LocationSnapshot(
    null,
    null,
    'Mencari lokasi…',
  );
  Map<MarkTemplate, TemplateCustomization> _templateConfigs = {};
  MarkTemplate _template = MarkTemplate.classic;
  bool _watermarkEnabled = true;
  bool _shutterPressed = false;
  WatermarkLayout _layout = WatermarkLayout.bottomLeft;
  DateTime _now = DateTime.now();
  String _photoCode = _newPhotoCode();
  String? _cameraError;
  File? _pendingGallery;
  bool _busy = false;
  bool _locating = false;
  bool _locationStarted = false;
  bool _navigationOpen = true;
  bool _configuring = false;
  bool _foreground = true;
  int _generation = 0;
  int _locationEpoch = 0;

  static String _newPhotoCode() {
    final random = Random.secure();
    return List.generate(
      14,
      (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[random.nextInt(32)],
    ).join();
  }

  WatermarkData _data(DateTime time) => WatermarkData(
    capturedAt: _session?.timeAt(time) ?? time,
    latitude: _session?.isManual == true
        ? _session!.latitude
        : _location.latitude,
    longitude: _session?.isManual == true
        ? _session!.longitude
        : _location.longitude,
    address: _session?.isManual == true
        ? _session!.address!
        : _location.address,
    layout: _layout,
    template: _template,
    customization: _templateConfigs[_template] ?? const TemplateCustomization(),
    enabled: _watermarkEnabled,
    isManual: _session?.isManual ?? false,
    photoCode: _photoCode,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && !_navigationOpen && _camera != null) {
        unawaited(_refreshLocation());
      }
    });
  }

  Future<void> _start() async {
    try {
      final settings = await _settings.load();
      ui.Image? logo;
      if (settings.logo != null) {
        final codec = await ui.instantiateImageCodec(settings.logo!);
        try {
          logo = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      if (!mounted) {
        logo?.dispose();
        return;
      }
      setState(() {
        _layout = settings.layout;
        _quality = settings.quality;
        _template = settings.template;
        _templateConfigs = settings.customizations;
        _watermarkEnabled = settings.enabled;
        _logo = logo;
      });
    } catch (_) {
      _message(
        'Pengaturan tersimpan gagal dibaca; menggunakan pengaturan dasar.',
      );
    }
    if (mounted) await _configureSession(first: true);
  }

  Future<void> _configureSession({bool first = false}) async {
    if (_configuring || _busy || _controlBusy) return;
    _configuring = true;
    _navigationOpen = true;
    await _releaseCamera();
    try {
      while (mounted) {
        if (!mounted) return;
        final mode = await showCaptureModeDialog(context);
        if (!mounted) return;
        CaptureSession? selection;
        if (mode == CaptureMode.real) {
          selection = const CaptureSession.real();
        } else if (mode == CaptureMode.fake) {
          selection = await Navigator.of(context).push<CaptureSession>(
            MaterialPageRoute(
              builder: (_) => ManualCaptureScreen(
                initial: _lastManual,
                initialLatitude: _location.latitude,
                initialLongitude: _location.longitude,
              ),
            ),
          );
        }
        if (!mounted) return;
        if (selection == null) {
          if (first) continue;
          break;
        }
        setState(() {
          _session = selection;
          if (selection!.isManual) _lastManual = selection;
          _locationStarted = false;
          _locating = false;
          _locationEpoch++;
          if (!selection.isManual) {
            _location = const LocationSnapshot(null, null, 'Mencari lokasi…');
          }
        });
        break;
      }
    } finally {
      _configuring = false;
      _navigationOpen = false;
      if (mounted && _session != null) await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || _session == null || _navigationOpen || !_foreground) return;
    final generation = ++_generation;
    await _cameraOperations.run(() => _initializeCameraNow(generation));
  }

  Future<void> _initializeCameraNow(int generation) async {
    if (!mounted ||
        generation != _generation ||
        _navigationOpen ||
        !_foreground ||
        _session == null) {
      return;
    }
    final previous = _camera;
    _camera = null;
    setState(() => _cameraError = null);
    CameraController? next;
    try {
      await previous?.dispose();
      if (!mounted || generation != _generation) return;
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw StateError('Kamera tidak ditemukan');
      _cameras = cameras;
      final main = CameraLenses.primary(cameras, _facing) ?? cameras.first;
      final selected = _useUltraWide
          ? CameraLenses.ultraWide(cameras, _facing) ?? main
          : main;
      _facing = selected.lensDirection;
      final zoomBase = _useUltraWide && selected != main ? 0.5 : 1.0;
      next = CameraController(selected, _quality.preset, enableAudio: false);
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      var range = const CameraZoomRange(1, 1);
      try {
        final limits = await Future.wait([
          next.getMinZoomLevel(),
          next.getMaxZoomLevel(),
        ]);
        if (limits[0] > 0 && limits[1] >= limits[0] && limits[1].isFinite) {
          range = CameraZoomRange(limits[0], limits[1]);
        }
      } catch (error) {
        debugPrint('Zoom capability unavailable: $error');
      }
      var appliedZoom = range.clamp(_zoom / zoomBase);
      try {
        await next.setZoomLevel(appliedZoom);
      } catch (_) {
        appliedZoom = range.clamp(1);
      }
      var appliedFlash = _facing == CameraLensDirection.back
          ? _flash
          : FlashMode.off;
      var flashAvailable = _facing == CameraLensDirection.back;
      try {
        await next.setFlashMode(appliedFlash);
      } catch (_) {
        appliedFlash = FlashMode.off;
        flashAvailable = false;
      }
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      setState(() {
        _camera = next;
        _zoomRanges[selected.name] = range;
        _zoom = appliedZoom * zoomBase;
        _flash = appliedFlash;
        _flashAvailable = flashAvailable;
      });
      if (!_locationStarted && _session?.mode == CaptureMode.real) {
        _locationStarted = true;
        unawaited(_refreshLocation());
      }
    } catch (error) {
      await next?.dispose();
      if (mounted && generation == _generation) {
        debugPrint('Camera initialization failed: $error');
        final code = error is CameraException ? error.code : 'Tidak tersedia';
        setState(
          () => _cameraError =
              'Kamera belum dapat dibuka ($code). Periksa izin kamera, lalu coba lagi.',
        );
      }
    }
  }

  bool get _canSwitchCamera =>
      CameraLenses.primary(
        _cameras,
        _facing == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front,
      ) !=
      null;

  bool _supportsZoom(double value) {
    final main = CameraLenses.primary(_cameras, _facing);
    if (main == null) return false;
    final range = _zoomRanges[main.name] ?? const CameraZoomRange(1, 1);
    return range.supports(value) ||
        (value == 0.5 && CameraLenses.ultraWide(_cameras, _facing) != null);
  }

  Future<void> _setZoom(double value) async {
    final camera = _camera;
    if (_busy || _controlBusy || camera == null || !_supportsZoom(value)) {
      return;
    }
    setState(() => _controlBusy = true);
    try {
      final main = CameraLenses.primary(_cameras, _facing)!;
      final primaryRange =
          _zoomRanges[main.name] ?? const CameraZoomRange(1, 1);
      final useUltra = value == 0.5 && !primaryRange.supports(value);
      if (useUltra != _useUltraWide) {
        setState(() {
          _useUltraWide = useUltra;
          _zoom = value;
        });
        await _initializeCamera();
      } else {
        final generation = _generation;
        await _cameraOperations.run(() async {
          if (!mounted || generation != _generation || _camera != camera) {
            return;
          }
          final base = _useUltraWide ? 0.5 : 1.0;
          final range =
              _zoomRanges[camera.description.name] ??
              const CameraZoomRange(1, 1);
          final applied = range.clamp(value / base);
          await camera.setZoomLevel(applied);
          if (mounted && generation == _generation) {
            setState(() => _zoom = applied * base);
          }
        });
      }
    } catch (_) {
      _message('Zoom tersebut belum dapat digunakan pada kamera ini.');
    } finally {
      if (mounted) setState(() => _controlBusy = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_busy || _controlBusy || _camera == null || !_canSwitchCamera) return;
    setState(() {
      _controlBusy = true;
      _facing = _facing == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _useUltraWide = false;
      _zoom = 1;
      _flash = FlashMode.off;
    });
    try {
      await _initializeCamera();
    } finally {
      if (mounted) setState(() => _controlBusy = false);
    }
  }

  String get _flashLabel => switch (_flash) {
    FlashMode.off => 'Mati',
    FlashMode.auto => 'Otomatis',
    FlashMode.always => 'Menyala',
    FlashMode.torch => 'Senter',
  };

  SwiftGlyph get _flashIcon => switch (_flash) {
    FlashMode.off => SwiftGlyph.flashOff,
    FlashMode.auto => SwiftGlyph.flashAuto,
    FlashMode.always => SwiftGlyph.flashOn,
    FlashMode.torch => SwiftGlyph.flashOn,
  };

  Future<void> _cycleFlash() async {
    final camera = _camera;
    if (_busy || _controlBusy || camera == null || !_flashAvailable) return;
    const modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final mode = modes[(modes.indexOf(_flash) + 1) % modes.length];
    final generation = _generation;
    setState(() => _controlBusy = true);
    try {
      await _cameraOperations.run(() async {
        if (!mounted || generation != _generation || _camera != camera) return;
        await camera.setFlashMode(mode);
        if (mounted && generation == _generation) setState(() => _flash = mode);
      });
    } catch (_) {
      if (mounted && _camera == camera) setState(() => _flashAvailable = false);
      _message('Flash tidak tersedia pada kamera ini.');
    } finally {
      if (mounted) setState(() => _controlBusy = false);
    }
  }

  void _onDrawerChanged(bool open) {
    if (!mounted) return;
    setState(() => _drawerOpen = open);
    final destination = _pendingDrawerAction;
    if (!open && destination != null) {
      _pendingDrawerAction = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (destination) {
          case CameraDestination.drive:
            unawaited(_openDrive());
          case CameraDestination.edit:
            unawaited(_openDrive(editPhotos: true));
          case CameraDestination.templates:
            unawaited(_openEdit());
          case CameraDestination.settings:
            unawaited(_openSettings());
        }
      });
    }
  }

  Future<void> _releaseCamera({bool notify = true}) async {
    ++_generation;
    final camera = _camera;
    _camera = null;
    if (mounted && notify) setState(() {});
    await _cameraOperations.run(() async {
      try {
        await camera?.dispose();
      } catch (error) {
        debugPrint('Camera cleanup failed: $error');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _foreground = false;
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (!_navigationOpen) {
        unawaited(_initializeCamera());
        unawaited(_refreshLocation());
      }
    }
  }

  Future<void> _refreshLocation() async {
    if (_locating || _session?.mode != CaptureMode.real) return;
    final epoch = _locationEpoch;
    setState(() => _locating = true);
    final location = await LocationService().read();
    if (!mounted ||
        epoch != _locationEpoch ||
        _session?.mode != CaptureMode.real) {
      return;
    }
    setState(() {
      _location = location;
      _locating = false;
    });
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _selectRatio(PhotoRatio ratio) {
    if (_ratio == ratio) return;
    HapticFeedback.selectionClick();
    setState(() => _ratio = ratio);
    _message(
      ratio == PhotoRatio.original
          ? 'Rasio asli dipilih. Seluruh bingkai kamera akan disimpan.'
          : 'Rasio ${ratio.label} diterapkan. Area di dalam bingkai akan disimpan.',
    );
  }

  void _finishBusy() {
    if (mounted) {
      setState(() => _busy = false);
    } else {
      _logo?.dispose();
      _logo = null;
    }
  }

  Future<void> _chooseLogo() async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      final previous = _logo;
      setState(() => _logo = image);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
      await _settings.saveLogo(bytes);
    } catch (error) {
      _message('Logo gagal dibuka/disimpan: $error');
    } finally {
      _finishBusy();
    }
  }

  Future<void> _openEdit() async {
    if (_busy || _controlBusy || _navigationOpen) return;
    _navigationOpen = true;
    try {
      if (!mounted) return;
      final choice = await showModalBottomSheet<WatermarkEditChoice>(
        context: context,
        isScrollControlled: true,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 320),
          reverseDuration: Duration(milliseconds: 260),
        ),
        builder: (_) => EditWatermarkSheet(
          layout: _layout,
          hasLogo: _logo != null,
          template: _template,
          enabled: _watermarkEnabled,
          logo: _logo,
        ),
      );
      if (!mounted || choice == null) return;
      switch (choice.action) {
        case WatermarkEditAction.mode:
          await _releaseCamera();
          await _configureSession();
        case WatermarkEditAction.logo:
          await _releaseCamera();
          await _chooseLogo();
        case WatermarkEditAction.removeLogo:
          await _settings.removeLogo();
          if (!mounted) return;
          final previous = _logo;
          setState(() => _logo = null);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => previous?.dispose(),
          );
        case WatermarkEditAction.template:
          if (choice.template == null) {
            setState(() => _watermarkEnabled = false);
            await _settings.update(enabled: false);
          } else {
            await _releaseCamera();
            if (!mounted) return;
            final selected = choice.template!;
            final result = await Navigator.of(context)
                .push<TemplateDesignResult>(
                  MaterialPageRoute(
                    builder: (_) => TemplateDesignerScreen(
                      data: _data(DateTime.now()).copyWith(
                        template: selected,
                        customization:
                            _templateConfigs[selected] ??
                            const TemplateCustomization(),
                      ),
                      logo: _logo,
                      aspectRatio: _ratio.aspectRatio ?? .75,
                    ),
                  ),
                );
            if (result != null && mounted) {
              if (result.logoBytes != null) {
                final codec = await ui.instantiateImageCodec(result.logoBytes!);
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
                final old = _logo;
                setState(() => _logo = image);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => old?.dispose(),
                );
                await _settings.saveLogo(result.logoBytes!);
              }
              if (!mounted) return;
              setState(() {
                _template = selected;
                _watermarkEnabled = true;
                _templateConfigs = {
                  ..._templateConfigs,
                  selected: result.customization,
                };
              });
              await _settings.update(
                template: selected,
                enabled: true,
                customization: result.customization,
              );
            }
          }
        case WatermarkEditAction.layout:
          if (choice.layout != null) {
            setState(() => _layout = choice.layout!);
            await _settings.saveLayout(choice.layout!);
          }
      }
    } catch (error) {
      _message('Pengaturan belum dapat disimpan: $error');
    } finally {
      _navigationOpen = false;
      if (mounted && _camera == null) await _initializeCamera();
    }
  }

  Future<void> _openSettings() async {
    if (_busy || _controlBusy || _navigationOpen) return;
    _navigationOpen = true;
    await _releaseCamera();
    try {
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      final settings = await _settings.load();
      if (mounted) setState(() => _quality = settings.quality);
    } catch (_) {
      _message('Pengaturan kamera belum dapat dimuat.');
    } finally {
      _navigationOpen = false;
      if (mounted) await _initializeCamera();
    }
  }

  Future<void> _openDrive({bool editPhotos = false}) async {
    if (_busy || _controlBusy || _navigationOpen) return;
    _navigationOpen = true;
    await _releaseCamera();
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GalleryScreen(editPhotos: editPhotos),
        ),
      );
    } finally {
      _navigationOpen = false;
      if (mounted) await _initializeCamera();
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_busy ||
        _controlBusy ||
        _drawerOpen ||
        camera == null ||
        _navigationOpen ||
        !camera.value.isInitialized) {
      return;
    }
    final data = _data(DateTime.now());
    final ratio = _ratio;
    setState(() => _busy = true);
    File? saved;
    XFile? raw;
    try {
      raw = await camera.takePicture();
      final source = await raw.readAsBytes();
      saved = await _storage.saveInternal(
        await _renderer.render(source, data, _logo, ratio: ratio),
      );
      try {
        final logoBytes = await _logo?.toByteData(
          format: ui.ImageByteFormat.png,
        );
        await PhotoProjectService().save(
          saved,
          source,
          data,
          ratio,
          logo: logoBytes?.buffer.asUint8List(
            logoBytes.offsetInBytes,
            logoBytes.lengthInBytes,
          ),
        );
      } catch (_) {
        _message(
          'Foto tersimpan, tetapi data edit ulang belum berhasil disimpan.',
        );
      }
      try {
        await _storage.saveToGallery(saved);
        _message('Foto tersimpan di perangkat dan galeri.');
      } catch (_) {
        if (mounted) setState(() => _pendingGallery = saved);
        _message(
          'Foto tersimpan di Drive lokal. Salinan galeri belum berhasil.',
        );
      }
      if (mounted) setState(() => _photoCode = _newPhotoCode());
    } catch (error) {
      _message('Pengambilan foto gagal: $error');
    } finally {
      if (saved != null && raw != null) {
        try {
          await File(raw.path).delete();
        } catch (_) {
          /* camera cache */
        }
      }
      _finishBusy();
    }
  }

  Future<void> _retryGallery() async {
    final file = _pendingGallery;
    if (file == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _storage.saveToGallery(file);
      if (mounted) setState(() => _pendingGallery = null);
      _message('Foto tersimpan di galeri.');
    } catch (_) {
      _message('Belum dapat menyalin ke galeri. Foto internal tetap aman.');
    } finally {
      _finishBusy();
    }
  }

  @override
  void dispose() {
    _foreground = false;
    ++_locationEpoch;
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _gpsTimer?.cancel();
    unawaited(_releaseCamera(notify: false));
    if (!_busy) _logo?.dispose();
    super.dispose();
  }

  Widget _viewfinder() {
    final camera = _camera;
    if (_session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF9CAAB8),
              size: 62,
            ),
            const SizedBox(height: 16),
            const Text(
              'Siap merekam cerita di lapangan',
              style: TextStyle(color: Color(0xFF68788A)),
            ),
            if (!_configuring)
              TextButton(
                onPressed: () => _configureSession(first: true),
                child: const Text('Pilih mode kamera'),
              ),
          ],
        ),
      );
    }
    if (_cameraError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF344459)),
              ),
              TextButton(
                onPressed: _initializeCamera,
                child: const Text(
                  'Coba lagi',
                  style: TextStyle(color: Color(0xFF087EF0)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (camera == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFCB30)),
      );
    }
    final nativeAspect = 1 / camera.value.aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(constraints.maxWidth, constraints.maxHeight);
        final target = _ratio.previewBounds(available);
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1000,
                  height: 1000 / nativeAspect,
                  child: CameraPreview(camera),
                ),
              ),
            ),
            IgnorePointer(
              child: TweenAnimationBuilder<Rect?>(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                tween: RectTween(end: target),
                builder: (context, frame, _) {
                  final rect = frame ?? target;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _RatioFramePainter(
                          frame: rect,
                          visible: _ratio != PhotoRatio.original,
                        ),
                      ),
                      Positioned.fromRect(
                        rect: rect,
                        child: ClipRect(
                          child: CustomPaint(
                            painter: WatermarkPainter(_data(_now), logo: _logo),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manual = _session?.isManual ?? false;
    final available =
        !_busy && !_controlBusy && !_navigationOpen && !_drawerOpen;
    final canCapture = available && _camera != null;
    return Scaffold(
      key: _scaffold,
      drawer: CameraNavigationDrawer(
        mode: _session == null
            ? 'belum dipilih'
            : manual
            ? 'Manual'
            : 'Live',
        onClose: () => _scaffold.currentState?.closeDrawer(),
        onSelected: (destination) {
          _pendingDrawerAction = destination;
          _scaffold.currentState?.closeDrawer();
        },
      ),
      drawerScrimColor: const Color(0x77000000),
      drawerEnableOpenDragGesture: available && _session != null,
      onDrawerChanged: _onDrawerChanged,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Buka menu',
                    onPressed: available && _session != null
                        ? () => _scaffold.currentState?.openDrawer()
                        : null,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const SwiftIcon(SwiftGlyph.menu, size: 25),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Swift Photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _flashAvailable
                        ? 'Flash: $_flashLabel'
                        : 'Flash tidak tersedia pada kamera ini',
                    onPressed: canCapture && _flashAvailable
                        ? _cycleFlash
                        : null,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: SwiftIcon(
                      _flashIcon,
                      size: 25,
                      color: _flash != FlashMode.off && _flashAvailable
                          ? const Color(0xFFB78A00)
                          : null,
                    ),
                  ),
                  IconButton(
                    tooltip: _canSwitchCamera
                        ? 'Ganti kamera'
                        : 'Kamera lain tidak tersedia',
                    onPressed: canCapture && _canSwitchCamera
                        ? _switchCamera
                        : null,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const SwiftIcon(SwiftGlyph.switchCamera, size: 27),
                  ),
                  const SizedBox(width: 5),
                  TextButton(
                    onPressed: !available || _configuring
                        ? null
                        : _configureSession,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD9DCDD)),
                      foregroundColor: const Color(0xFF171A1F),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                    ),
                    child: Text(
                      _session == null
                          ? 'Mode'
                          : manual
                          ? 'Manual'
                          : 'Live',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _viewfinder(),
                    if (_session != null)
                      Align(
                        alignment: Alignment.topCenter,
                        child: RatioControl(
                          ratio: _ratio,
                          enabled: canCapture,
                          facing: _facing == CameraLensDirection.front
                              ? 'DEPAN'
                              : 'BELAKANG',
                          onSelected: _selectRatio,
                        ),
                      ),
                    if (_session != null)
                      Align(
                        alignment: const Alignment(1, -0.15),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ZoomControls(
                            zoom: _zoom,
                            supports: _supportsZoom,
                            enabled: canCapture,
                            onSelected: _setZoom,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_pendingGallery != null)
              TextButton.icon(
                onPressed: _busy ? null : _retryGallery,
                icon: const Icon(Icons.save_alt, size: 16),
                label: const Text('Ulangi simpan ke galeri'),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PHOTO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavigationControl(
                          label: 'Drive',
                          icon: SwiftGlyph.folder,
                          onTap: available ? _openDrive : null,
                        ),
                        Semantics(
                          label: 'Ambil foto',
                          button: true,
                          enabled: canCapture,
                          child: Tooltip(
                            message: 'Ambil foto',
                            child: InkResponse(
                              onTap: canCapture ? _capture : null,
                              onHighlightChanged: (pressed) =>
                                  setState(() => _shutterPressed = pressed),
                              radius: 45,
                              child: Opacity(
                                opacity: canCapture || _busy ? 1 : 0.35,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOutCubic,
                                  width: 82,
                                  height: 82,
                                  transformAlignment: Alignment.center,
                                  transform: Matrix4.diagonal3Values(
                                    _shutterPressed ? .94 : 1,
                                    _shutterPressed ? .94 : 1,
                                    1,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF171A1F),
                                      width: 5,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: _busy
                                        ? const Padding(
                                            padding: EdgeInsets.all(19),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF171A1F),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _NavigationControl(
                          label: 'Template',
                          icon: SwiftGlyph.edit,
                          onTap: available ? _openEdit : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioFramePainter extends CustomPainter {
  const _RatioFramePainter({required this.frame, required this.visible});

  final Rect frame;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible || frame.isEmpty) return;
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = const Color(0x26000000));
    canvas.drawRect(
      frame.deflate(.75),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    const length = 22.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final segments in <List<Offset>>[
      [
        frame.topLeft + const Offset(length, 0),
        frame.topLeft,
        frame.topLeft + const Offset(0, length),
      ],
      [
        frame.topRight + const Offset(-length, 0),
        frame.topRight,
        frame.topRight + const Offset(0, length),
      ],
      [
        frame.bottomLeft + const Offset(0, -length),
        frame.bottomLeft,
        frame.bottomLeft + const Offset(length, 0),
      ],
      [
        frame.bottomRight + const Offset(-length, 0),
        frame.bottomRight,
        frame.bottomRight + const Offset(0, -length),
      ],
    ]) {
      canvas.drawPath(Path()..addPolygon(segments, false), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RatioFramePainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.visible != visible;
}

class _NavigationControl extends StatelessWidget {
  const _NavigationControl({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final SwiftGlyph icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwiftIcon(
              icon,
              size: 29,
              color: onTap == null ? Colors.black26 : const Color(0xFF343A42),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: onTap == null ? Colors.black26 : const Color(0xFF343A42),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
