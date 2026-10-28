import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_data.dart';
import '../models/camera_options.dart';
import '../models/watermark_regions.dart';

/// One canvas for the camera preview and the full-resolution exported photo.
class WatermarkPainter extends CustomPainter {
  WatermarkPainter(
    this.data, {
    this.logo,
    this.thumbnail = false,
    this.drawLogo = true,
  });
  final WatermarkData data;
  final ui.Image? logo;
  final bool thumbnail;
  final bool drawLogo;
  static const gold = Color(0xFFFFCB30);

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double width,
    double fontSize, {
    Color color = Colors.white,
    int lines = 1,
    FontWeight weight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontSize: fontSize,
          height: 1.05,
          color: color,
          fontWeight: weight,
          shadows: const [
            Shadow(
              color: Color(0xA6000000),
              blurRadius: 4,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  void _box(Canvas canvas, Rect rect, Color color, {double radius = 0}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  void _pin(Canvas canvas, Offset center, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + 24)
      ..cubicTo(
        center.dx - 34,
        center.dy - 10,
        center.dx - 20,
        center.dy - 32,
        center.dx,
        center.dy - 32,
      )
      ..cubicTo(
        center.dx + 20,
        center.dy - 32,
        center.dx + 34,
        center.dy - 10,
        center.dx,
        center.dy + 24,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      Offset(center.dx, center.dy - 10),
      7,
      Paint()..color = Colors.white,
    );
  }

  void _locationCard(Canvas canvas, double x, double y) {
    _box(
      canvas,
      Rect.fromLTWH(x, y, 210, 220),
      const Color(0xF2F6FAFC),
      radius: 10,
    );
    _pin(canvas, Offset(x + 105, y + 80), const Color(0xFF159BF3));
    _text(
      canvas,
      'Pin lokasi',
      Offset(x + 12, y + 122),
      186,
      27,
      color: const Color(0xFF354450),
    );
    _text(
      canvas,
      data.latitude?.toStringAsFixed(4) ?? '--',
      Offset(x + 12, y + 163),
      186,
      21,
      color: const Color(0xFF354450),
    );
  }

  void _template(
    Canvas canvas,
    double x,
    double y,
    double width,
    Color accent,
  ) {
    final template = data.template;
    final hasPin = [
      MarkTemplate.map,
      MarkTemplate.visit,
      MarkTemplate.indomie,
      MarkTemplate.jt,
    ].contains(template);
    final textWidth = hasPin
        ? width - 240
        : template == MarkTemplate.portrait
        ? width - 180
        : width;
    if (hasPin) _locationCard(canvas, x + width - 210, y + 8);
    if (template.branded &&
        logo == null &&
        data.customization.showLogo &&
        drawLogo) {
      // Wordmark fallback; an uploaded company logo replaces this text.
      _box(canvas, Rect.fromLTWH(x, y - 85, 300, 65), Colors.white, radius: 3);
      _text(
        canvas,
        template.label,
        Offset(x + 10, y - 77),
        280,
        42,
        color: accent,
        weight: FontWeight.bold,
      );
    }
    switch (template.style) {
      case MarkStyle.clock:
        _text(canvas, data.clock, Offset(x, y), 278, 128);
        _box(canvas, Rect.fromLTWH(x + 294, y + 12, 4, 110), accent);
        _text(
          canvas,
          data.shortMonthDay,
          Offset(x + 318, y + 14),
          textWidth - 318,
          40,
        );
        _text(
          canvas,
          '${data.capturedAt.year}',
          Offset(x + 318, y + 76),
          textWidth - 318,
          36,
        );
        _text(
          canvas,
          data.address,
          Offset(x, y + 145),
          textWidth,
          34,
          lines: 2,
        );
        _text(
          canvas,
          data.compassCoordinates,
          Offset(x, y + 231),
          textWidth,
          25,
        );
        if (template == MarkTemplate.portrait && logo == null) {
          // Photo slot is intentionally neutral until the user selects a portrait/logo.
          canvas.drawCircle(
            Offset(x + width - 80, y + 50),
            32,
            Paint()..color = Colors.white38,
          );
          _box(
            canvas,
            Rect.fromLTWH(x + width - 136, y + 88, 112, 100),
            Colors.white24,
            radius: 22,
          );
        }
      case MarkStyle.compact:
      case MarkStyle.simple:
        if (template.style == MarkStyle.simple) {
          _box(canvas, Rect.fromLTWH(x, y + 98, 4, 54), accent);
          _text(
            canvas,
            '${data.numericDate} ${data.clock}',
            Offset(x + 22, y + 102),
            width - 22,
            40,
          );
        } else {
          if (template == MarkTemplate.custom ||
              template == MarkTemplate.service) {
            _text(
              canvas,
              template == MarkTemplate.service ? 'Service Name' : 'Your Title',
              Offset(x + 22, y - 42),
              textWidth - 22,
              34,
            );
          }
          _box(canvas, Rect.fromLTWH(x, y + 15, 4, 230), accent);
          _text(
            canvas,
            '${data.numericDate} ${data.clock}',
            Offset(x + 22, y + 13),
            textWidth - 22,
            33,
          );
          _text(
            canvas,
            data.address,
            Offset(x + 22, y + 81),
            textWidth - 22,
            34,
            lines: 2,
          );
          _text(
            canvas,
            data.compassCoordinates,
            Offset(x + 22, y + 202),
            textWidth - 22,
            29,
          );
        }
      case MarkStyle.badge:
        final patrol =
            template == MarkTemplate.security ||
            template == MarkTemplate.g4s ||
            template == MarkTemplate.pln;
        if (patrol) {
          _box(
            canvas,
            Rect.fromLTWH(x, y - 6, textWidth, 270),
            template == MarkTemplate.pln
                ? const Color(0xD943484B)
                : const Color(0xFF4155BD),
          );
          _box(
            canvas,
            Rect.fromLTWH(x, y - 6, textWidth, 78),
            template == MarkTemplate.pln
                ? const Color(0xFF3F4447)
                : const Color(0xFF343D7E),
          );
          _text(
            canvas,
            template == MarkTemplate.pln ? 'Indikator' : template.label,
            Offset(x + 80, y + 9),
            textWidth - 100,
            42,
            color: template == MarkTemplate.pln
                ? const Color(0xFFCDDF39)
                : gold,
            weight: FontWeight.bold,
          );
          _pin(canvas, Offset(x + 36, y + 43), gold);
          _box(canvas, Rect.fromLTWH(x, y + 78, textWidth, 2), gold);
          _text(
            canvas,
            data.clock,
            Offset(x + 20, y + 93),
            255,
            90,
            color: gold,
          );
          _text(
            canvas,
            data.numericDate,
            Offset(x + 285, y + 123),
            textWidth - 305,
            33,
          );
          _box(
            canvas,
            Rect.fromLTWH(x + 20, y + 207, 5, 35),
            template == MarkTemplate.pln
                ? const Color(0xFFCDDF39)
                : Colors.redAccent,
          );
          _text(
            canvas,
            data.address,
            Offset(x + 40, y + 196),
            textWidth - 60,
            32,
            lines: 2,
          );
          break;
        }
        final completed =
            template == MarkTemplate.completed ||
            template == MarkTemplate.adhi ||
            template == MarkTemplate.kfc;
        final clockIn = [
          MarkTemplate.clockIn,
          MarkTemplate.aice,
          MarkTemplate.qmb,
          MarkTemplate.spx,
          MarkTemplate.wahana,
          MarkTemplate.jt,
        ].contains(template);
        final cleaned =
            template == MarkTemplate.cleaned || template == MarkTemplate.tss;
        if (clockIn) {
          _box(canvas, Rect.fromLTWH(x, y, 540, 85), Colors.white, radius: 5);
          _box(canvas, Rect.fromLTWH(x + 3, y + 3, 265, 79), gold, radius: 3);
          final label = template == MarkTemplate.aice
              ? 'CLOCK IN'
              : template == MarkTemplate.clockIn
              ? 'CLOCK IN'
              : template == MarkTemplate.jt
              ? 'Visit'
              : 'e-Absensi';
          _text(
            canvas,
            label,
            Offset(x + 15, y + 15),
            245,
            43,
            color: const Color(0xFF20252A),
            weight: FontWeight.bold,
          );
          _text(
            canvas,
            data.clock,
            Offset(x + 280, y + 4),
            245,
            68,
            color: const Color(0xFF075AB1),
            weight: FontWeight.bold,
          );
        } else if (template == MarkTemplate.timeProof) {
          _box(
            canvas,
            Rect.fromLTWH(x, y, 300, 85),
            const Color(0xFFF4F7FB),
            radius: 10,
          );
          _text(
            canvas,
            data.clock,
            Offset(x + 24, y + 3),
            260,
            74,
            color: const Color(0xFF0763BD),
            weight: FontWeight.bold,
          );
        } else if (template == MarkTemplate.services) {
          _box(canvas, Rect.fromLTWH(x, y, 390, 85), Colors.white, radius: 8);
          _text(
            canvas,
            data.clock,
            Offset(x + 18, y + 5),
            245,
            68,
            color: gold,
          );
          _text(
            canvas,
            '♥',
            Offset(x + 280, y + 8),
            85,
            67,
            color: const Color(0xFF0EB04B),
          );
        } else if (template == MarkTemplate.activity) {
          _box(
            canvas,
            Rect.fromLTWH(x, y, 390, 85),
            const Color(0xF0202424),
            radius: 8,
          );
          _text(canvas, data.clock, Offset(x + 18, y + 5), 255, 68);
          _pin(canvas, Offset(x + 330, y + 48), const Color(0xFF0EB04B));
        } else if (completed) {
          _box(
            canvas,
            Rect.fromLTWH(x, y, 470, 85),
            template == MarkTemplate.kfc
                ? const Color(0xFFFF1429)
                : const Color(0xFF46211A),
            radius: 6,
          );
          _text(canvas, data.clock, Offset(x + 98, y + 2), 250, 72);
          canvas.drawCircle(Offset(x + 420, y + 42), 25, Paint()..color = gold);
          final tick = Path()
            ..moveTo(x + 407, y + 42)
            ..lineTo(x + 418, y + 52)
            ..lineTo(x + 435, y + 31);
          canvas.drawPath(
            tick,
            Paint()
              ..color = const Color(0xFF442A10)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5,
          );
        } else if (cleaned) {
          _text(canvas, '★★★★★', Offset(x + 28, y - 31), 350, 27, color: gold);
          _box(canvas, Rect.fromLTWH(x, y, 470, 85), accent, radius: 3);
          _box(canvas, Rect.fromLTWH(x, y, 250, 85), const Color(0xFF07618A));
          _text(canvas, 'Cleaned', Offset(x + 16, y + 18), 220, 47);
          _text(canvas, data.clock, Offset(x + 267, y + 9), 190, 61);
        } else if (template == MarkTemplate.express) {
          _box(
            canvas,
            Rect.fromLTWH(x, y, 340, 85),
            const Color(0xFFEF1423),
            radius: 5,
          );
          _text(canvas, data.clock, Offset(x + 16, y + 3), 240, 73);
          _text(canvas, '✓', Offset(x + 267, y + 17), 65, 47);
        } else {
          _box(canvas, Rect.fromLTWH(x, y, 470, 85), accent, radius: 6);
          _text(
            canvas,
            template.label,
            Offset(x + 14, y + 9),
            260,
            32,
            weight: FontWeight.bold,
          );
          _text(canvas, data.clock, Offset(x + 280, y + 9), 180, 57);
        }
        _box(canvas, Rect.fromLTWH(x, y + 108, 4, 142), accent);
        _text(
          canvas,
          data.numericDate,
          Offset(x + 20, y + 106),
          textWidth - 20,
          32,
        );
        _text(
          canvas,
          data.address,
          Offset(x + 20, y + 157),
          textWidth - 20,
          32,
          lines: 2,
        );
        _text(
          canvas,
          data.compassCoordinates,
          Offset(x + 20, y + 235),
          textWidth - 20,
          24,
        );
      case MarkStyle.sheet:
        final sheet = template == MarkTemplate.sheet;
        final heading =
            template == MarkTemplate.construction ||
                template == MarkTemplate.hkjaya
            ? 'Construction Record'
            : template == MarkTemplate.project
            ? 'DEVELOPER'
            : template.label;
        _box(
          canvas,
          Rect.fromLTWH(x, y, width, 258),
          sheet ? const Color(0xD5424A4C) : const Color(0xECDFE1E4),
        );
        _box(
          canvas,
          Rect.fromLTWH(x, y, width, 55),
          sheet ? const Color(0xFF3F514E) : accent,
        );
        _text(
          canvas,
          heading,
          Offset(x + 16, y + 9),
          width - 32,
          36,
          color: sheet ? accent : Colors.white,
          weight: FontWeight.bold,
        );
        final ink = sheet ? Colors.white : const Color(0xFF20252A);
        _text(canvas, 'Waktu', Offset(x + 16, y + 72), 160, 29, color: ink);
        _text(
          canvas,
          data.timestamp,
          Offset(x + 190, y + 72),
          width - 210,
          29,
          color: ink,
        );
        _text(canvas, 'Alamat', Offset(x + 16, y + 117), 160, 29, color: ink);
        _text(
          canvas,
          data.address,
          Offset(x + 190, y + 117),
          width - 210,
          30,
          lines: 2,
          color: ink,
        );
        _text(canvas, 'GPS', Offset(x + 16, y + 210), 160, 26, color: ink);
        _text(
          canvas,
          data.compassCoordinates,
          Offset(x + 190, y + 210),
          width - 210,
          25,
          color: ink,
        );
        final line = Paint()
          ..color = sheet ? accent : const Color(0x4459636C)
          ..strokeWidth = 1.3;
        canvas.drawLine(
          Offset(x + 175, y + 55),
          Offset(x + 175, y + 258),
          line,
        );
        for (final dy in [55.0, 109.0, 201.0, 258.0]) {
          canvas.drawLine(Offset(x, y + dy), Offset(x + width, y + dy), line);
        }
      case MarkStyle.inspection:
        _box(canvas, Rect.fromLTWH(x, y - 54, 240, 42), accent, radius: 3);
        _text(
          canvas,
          template == MarkTemplate.weather ? 'Cuaca: --' : 'Arah: --',
          Offset(x + 10, y - 49),
          225,
          27,
        );
        _box(
          canvas,
          Rect.fromLTWH(x + 260, y - 54, 215, 42),
          const Color(0xC04A4E53),
          radius: 3,
        );
        _text(canvas, 'Elevasi: --', Offset(x + 270, y - 49), 195, 27);
        _box(
          canvas,
          Rect.fromLTWH(x, y, width, 62),
          const Color(0xB340444C),
          radius: 6,
        );
        _text(
          canvas,
          data.compassCoordinates,
          Offset(x + 14, y + 10),
          width - 28,
          35,
        );
        _box(canvas, Rect.fromLTWH(x, y + 90, 4, 160), accent);
        _text(
          canvas,
          '${data.numericDate} ${data.clock}',
          Offset(x + 22, y + 90),
          width - 22,
          31,
        );
        _text(
          canvas,
          data.address,
          Offset(x + 22, y + 145),
          width - 22,
          34,
          lines: 2,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!data.enabled) return;
    final scale = size.width / 1000;
    final height = size.height / scale;
    final accent = Color(data.template.color);
    final width = data.layout == WatermarkLayout.footer ? 952.0 : 820.0;
    final x = data.layout == WatermarkLayout.bottomRight ? 156.0 : 24.0;
    final y = height - 350;
    canvas.save();
    canvas.scale(scale);
    final gradient = Rect.fromLTWH(0, height - 480, 1000, 480);
    if (!thumbnail) {
      canvas.drawRect(
        gradient,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0x99000000)],
          ).createShader(gradient),
      );
    }
    canvas.save();
    final visible = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, 1000, height));
    for (final field in WatermarkRegions.forData(data, height).entries) {
      final hidden = switch (field.key) {
        WatermarkField.dateTime ||
        WatermarkField.date ||
        WatermarkField.time => !data.customization.showTime,
        WatermarkField.location => !data.customization.showAddress,
        WatermarkField.coordinates => !data.customization.showCoordinates,
        WatermarkField.code => false,
      };
      if (hidden) visible.addRect(field.value);
    }
    canvas.clipPath(visible);
    _template(canvas, x, y, width, accent);
    canvas.restore();
    if (data.customization.showCode) {
      canvas.drawLine(
        Offset(x, height - 65),
        Offset(x + width, height - 65),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 1,
      );
      // Local Swift Photo ID; this is not a Timemark verification certificate.
      final shield = Path()
        ..moveTo(x + 14, height - 57)
        ..quadraticBezierTo(x + 20, height - 52, x + 28, height - 51)
        ..lineTo(x + 27, height - 39)
        ..quadraticBezierTo(x + 25, height - 29, x + 14, height - 23)
        ..quadraticBezierTo(x + 3, height - 29, x + 1, height - 39)
        ..lineTo(x, height - 51)
        ..quadraticBezierTo(x + 8, height - 52, x + 14, height - 57)
        ..close();
      final outline = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(shield, outline);
      final check = Path()
        ..moveTo(x + 7, height - 41)
        ..lineTo(x + 12, height - 36)
        ..lineTo(x + 21, height - 46);
      canvas.drawPath(
        check,
        Paint()
          ..color = Colors.white70
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      _text(
        canvas,
        'Photo Code: ${data.photoCode}',
        Offset(x + 35, height - 53),
        width - 35,
        27,
        weight: FontWeight.w600,
      );
    }
    if (logo != null && drawLogo && data.customization.showLogo) {
      final rect = data.customization.logoRect(
        Size(1000, height),
        logo!.width / logo!.height,
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(rect.shortestSide * data.customization.logoRadius),
        ),
      );
      paintImage(
        canvas: canvas,
        rect: rect,
        image: logo!,
        fit: BoxFit.contain,
        opacity: data.customization.logoOpacity,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.logo != logo ||
      oldDelegate.thumbnail != thumbnail ||
      oldDelegate.drawLogo != drawLogo;
}

class WatermarkRenderer {
  Future<Uint8List> render(
    Uint8List source,
    WatermarkData data,
    ui.Image? logo, {
    PhotoRatio ratio = PhotoRatio.original,
  }) async {
    final codec = await ui.instantiateImageCodec(source);
    ui.Image? photo;
    ui.Image? output;
    try {
      photo = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final crop = ratio.cropBounds(photo.width, photo.height);
      final size = crop.size;
      canvas.drawImageRect(
        photo,
        crop,
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high,
      );
      WatermarkPainter(data, logo: logo).paint(canvas, size);
      final picture = recorder.endRecording();
      try {
        output = await picture.toImage(size.width.toInt(), size.height.toInt());
      } finally {
        picture.dispose();
      }
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Gagal membuat file watermark');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      output?.dispose();
      photo?.dispose();
      codec.dispose();
    }
  }
}
