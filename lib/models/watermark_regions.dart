import 'dart:ui';
import 'watermark_data.dart';

enum WatermarkField { dateTime, date, time, location, coordinates, code }

/// Coordinates shared by the editor with the 1000-unit watermark canvas.
class WatermarkRegions {
  static Map<WatermarkField, Rect> forData(WatermarkData data, double height) {
    if (!data.enabled) return {};
    final x = data.layout == WatermarkLayout.bottomRight ? 156.0 : 24.0;
    final w = data.layout == WatermarkLayout.footer ? 952.0 : 820.0;
    final y = height - 350;
    final regions = <WatermarkField, Rect>{
      WatermarkField.code: Rect.fromLTWH(x, height - 62, w - 105, 56),
    };
    final patrol = [
      MarkTemplate.security,
      MarkTemplate.g4s,
      MarkTemplate.pln,
    ].contains(data.template);
    switch (data.template.style) {
      case MarkStyle.clock:
        regions.addAll({
          WatermarkField.time: Rect.fromLTWH(x, y, 278, 132),
          WatermarkField.date: Rect.fromLTWH(x + 312, y, w - 312, 132),
          WatermarkField.location: Rect.fromLTWH(x, y + 140, w, 85),
          WatermarkField.coordinates: Rect.fromLTWH(x, y + 228, w, 36),
        });
      case MarkStyle.compact:
        regions.addAll({
          WatermarkField.dateTime: Rect.fromLTWH(x, y + 5, w, 65),
          WatermarkField.location: Rect.fromLTWH(x, y + 78, w, 85),
          WatermarkField.coordinates: Rect.fromLTWH(x, y + 200, w, 44),
        });
      case MarkStyle.simple:
        regions[WatermarkField.dateTime] = Rect.fromLTWH(x, y + 95, w, 65);
      case MarkStyle.badge:
        if (patrol) {
          regions.addAll({
            WatermarkField.time: Rect.fromLTWH(x + 15, y + 90, 260, 99),
            WatermarkField.date: Rect.fromLTWH(x + 280, y + 115, w - 300, 65),
            WatermarkField.location: Rect.fromLTWH(x + 15, y + 193, w - 30, 71),
          });
        } else {
          regions.addAll({
            WatermarkField.time: Rect.fromLTWH(x, y, w, 85),
            WatermarkField.date: Rect.fromLTWH(x, y + 103, w, 46),
            WatermarkField.location: Rect.fromLTWH(x, y + 153, w, 77),
            WatermarkField.coordinates: Rect.fromLTWH(x, y + 231, w, 36),
          });
        }
      case MarkStyle.sheet:
        regions.addAll({
          WatermarkField.dateTime: Rect.fromLTWH(x, y + 65, w, 42),
          WatermarkField.location: Rect.fromLTWH(x, y + 113, w, 84),
          WatermarkField.coordinates: Rect.fromLTWH(x, y + 207, w, 48),
        });
      case MarkStyle.inspection:
        regions.addAll({
          WatermarkField.coordinates: Rect.fromLTWH(x, y, w, 62),
          WatermarkField.dateTime: Rect.fromLTWH(x, y + 85, w, 48),
          WatermarkField.location: Rect.fromLTWH(x, y + 141, w, 87),
        });
    }
    return regions;
  }
}
