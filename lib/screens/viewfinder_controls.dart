import 'package:flutter/material.dart';
import '../models/camera_options.dart';
import '../widgets/swift_icon.dart';

class RatioControl extends StatelessWidget {
  const RatioControl({
    super.key,
    required this.ratio,
    required this.onSelected,
    required this.enabled,
    required this.facing,
  });
  final PhotoRatio ratio;
  final ValueChanged<PhotoRatio> onSelected;
  final bool enabled;
  final String facing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        PopupMenuButton<PhotoRatio>(
          key: const ValueKey('photo-ratio-menu'),
          tooltip: 'Rasio foto',
          enabled: enabled,
          initialValue: ratio,
          color: const Color(0xFF272B30),
          onSelected: onSelected,
          itemBuilder: (_) => PhotoRatio.values
              .map(
                (value) => PopupMenuItem(
                  key: ValueKey('photo-ratio-${value.name}'),
                  value: value,
                  child: Row(
                    children: [
                      Text(
                        value.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      if (value == ratio)
                        const Icon(
                          Icons.check,
                          color: Color(0xFFFFCB30),
                          size: 18,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SwiftIcon(
                  SwiftGlyph.ratio,
                  size: 17,
                  color: Colors.white70,
                ),
                const SizedBox(width: 7),
                Text(
                  ratio.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const SwiftIcon(
                  SwiftGlyph.chevronDown,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Text(
          facing,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            letterSpacing: 1.8,
          ),
        ),
      ],
    ),
  );
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.zoom,
    required this.supports,
    required this.enabled,
    required this.onSelected,
  });
  final double zoom;
  final bool Function(double) supports;
  final bool enabled;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in [2.0, 1.0, 0.5])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Builder(
              builder: (context) {
                final label = value == 0.5 ? '0,5×' : '${value.toInt()}×';
                final selected = (zoom - value).abs() < 0.01;
                final supported = supports(value);
                final active = enabled && supported;
                return Tooltip(
                  message: supported
                      ? 'Zoom $label'
                      : 'Zoom $label tidak tersedia pada kamera ini',
                  child: Semantics(
                    label: 'Zoom $label',
                    selected: selected,
                    button: true,
                    enabled: active,
                    excludeSemantics: true,
                    onTap: active ? () => onSelected(value) : null,
                    child: InkWell(
                      onTap: active ? () => onSelected(value) : null,
                      borderRadius: BorderRadius.circular(28),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: selected ? 36 : 26,
                            height: selected ? 36 : 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0x33000000)
                                  : const Color(0x16000000),
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(color: Colors.white, width: 1.4)
                                  : null,
                            ),
                            child: Text(
                              value == 0.5
                                  ? '0.5'
                                  : selected
                                  ? '${value.toInt()}x'
                                  : '${value.toInt()}',
                              style: TextStyle(
                                fontSize: selected ? 14 : 12,
                                fontWeight: FontWeight.w600,
                                shadows: supported
                                    ? const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ]
                                    : const [],
                                color: !supported
                                    ? Colors.white38
                                    : Colors.white,
                              ),
                            ),
                          ),
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
