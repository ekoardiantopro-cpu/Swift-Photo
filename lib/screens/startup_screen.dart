import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/animated_swift_bird.dart';
import 'camera_screen.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});
  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _ready = false;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180),
    child: _ready
        ? const CameraScreen(key: ValueKey('camera'))
        : StartupScreen(
            key: const ValueKey('splash'),
            firstFrameReady:
                WidgetsBinding.instance.waitUntilFirstFrameRasterized,
            onComplete: () {
              if (mounted) setState(() => _ready = true);
            },
          ),
  );
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 650),
    this.firstFrameReady,
  });
  final VoidCallback onComplete;
  final Duration duration;
  final Future<void>? firstFrameReady;
  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  Future<void> _startCountdown() async {
    final ready = widget.firstFrameReady;
    if (ready != null) await ready;
    if (mounted) {
      _timer = Timer(widget.duration, widget.onComplete);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _flight.stop();
    } else {
      _flight.repeat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flight.dispose();
    super.dispose();
  }

  Widget _content(BoxConstraints bounds) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedBuilder(
        animation: _flight,
        builder: (context, _) {
          final size = math.min(bounds.maxWidth * .68, 280.0);
          return SizedBox.square(
            dimension: size + 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _flight.value * .10,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
                Container(
                  width: size * .86,
                  height: size * .86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF3),
                    borderRadius: BorderRadius.circular(52),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44102561),
                        blurRadius: 35,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: size * .72,
                  child: AnimatedSwiftBird(phase: _flight.value),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 28),
      const Text(
        'Swift Photo',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 35,
          letterSpacing: -.8,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Snap for Proof',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 19,
          letterSpacing: 2.2,
          color: Color(0xFFDAEFFF),
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 38),
      SizedBox(
        width: 112,
        child: LinearProgressIndicator(
          value: MediaQuery.disableAnimationsOf(context) ? .6 : null,
          minHeight: 3,
          color: const Color(0xFFFFD35A),
          backgroundColor: const Color(0x44FFFFFF),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF087BEA),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF087BEA),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123F9D), Color(0xFF087BEA), Color(0xFF08ACE6)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: _content(bounds),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
