import 'package:flutter/material.dart';

/// Subtle touch feedback shared by every screen, without intercepting gestures.
class InteractiveEffects extends StatefulWidget {
  const InteractiveEffects({super.key, required this.child});
  final Widget child;
  @override
  State<InteractiveEffects> createState() => _InteractiveEffectsState();
}

class _InteractiveEffectsState extends State<InteractiveEffects>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  Offset? _point;
  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      setState(() => _point = event.localPosition);
      _pulse.forward(from: 0);
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final point = _point;
              if (point == null ||
                  !_pulse.isAnimating ||
                  MediaQuery.disableAnimationsOf(context)) {
                return const SizedBox.shrink();
              }
              final size = 12 + 32 * _pulse.value;
              return Stack(
                children: [
                  Positioned(
                    left: point.dx - size / 2,
                    top: point.dy - size / 2,
                    child: Opacity(
                      opacity: (1 - _pulse.value) * .32,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x5538A9FF),
                          border: Border.all(
                            color: const Color(0xFF38A9FF),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
