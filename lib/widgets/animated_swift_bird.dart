import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A native vector version of the app mascot; only its wings and body animate.
class AnimatedSwiftBird extends StatelessWidget {
  const AnimatedSwiftBird({super.key, required this.phase});
  final double phase;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BirdPainter(phase));
}

class _BirdPainter extends CustomPainter {
  const _BirdPainter(this.phase);
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 300;
    canvas.save();
    canvas.translate(
      (size.width - 300 * scale) / 2,
      (size.height - 300 * scale) / 2,
    );
    canvas.scale(scale);
    final flap = math.sin(phase * math.pi * 2);
    canvas.translate(0, flap * 3);
    const navy = Color(0xFF102A4B), gold = Color(0xFFFFC424);
    final wing = Path()
      ..moveTo(153, 160)
      ..cubicTo(106, 151, 63, 109 + flap * 15, 46, 38 + flap * 30)
      ..cubicTo(109, 95 + flap * 10, 153, 96, 170, 150)
      ..close();
    canvas.drawPath(wing, Paint()..color = navy);
    final farWing = Path()
      ..moveTo(145, 173)
      ..cubicTo(96, 172, 42, 148 + flap * 14, 22, 95 + flap * 38)
      ..cubicTo(87, 132, 130, 132, 155, 160)
      ..close();
    canvas.drawPath(farWing, Paint()..color = navy);
    final glint = Path()
      ..moveTo(140, 152)
      ..cubicTo(100, 134, 72, 97 + flap * 15, 60, 66 + flap * 30)
      ..cubicTo(109, 116, 128, 119, 140, 152)
      ..close();
    canvas.drawPath(glint, Paint()..color = gold);
    final body = Path()
      ..moveTo(173, 139)
      ..cubicTo(236, 126, 256, 170, 218, 206)
      ..cubicTo(183, 239, 140, 225, 108, 208)
      ..lineTo(28, 254)
      ..lineTo(75, 212)
      ..lineTo(12, 231)
      ..lineTo(117, 174)
      ..quadraticBezierTo(145, 150, 173, 139)
      ..close();
    canvas.drawPath(body, Paint()..color = navy);
    final belly = Path()
      ..moveTo(203, 171)
      ..quadraticBezierTo(213, 212, 169, 217)
      ..quadraticBezierTo(142, 222, 119, 206)
      ..quadraticBezierTo(167, 198, 203, 171)
      ..close();
    canvas.drawPath(belly, Paint()..color = Colors.white);
    final tail = Path()
      ..moveTo(114, 191)
      ..lineTo(42, 238)
      ..lineTo(85, 201)
      ..close();
    canvas.drawPath(tail, Paint()..color = gold);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(167, 101, 90, 72),
        const Radius.circular(20),
      ),
      Paint()..color = navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(182, 90, 34, 22),
        const Radius.circular(6),
      ),
      Paint()..color = navy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(190, 95, 19, 9),
        const Radius.circular(3),
      ),
      Paint()..color = gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(176, 109, 73, 55),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(const Offset(208, 135), 23, Paint()..color = gold);
    canvas.drawCircle(const Offset(208, 135), 18, Paint()..color = navy);
    canvas.drawCircle(const Offset(214, 128), 6, Paint()..color = Colors.white);
    final beak = Path()
      ..moveTo(244, 133)
      ..quadraticBezierTo(263, 120, 279, 136)
      ..quadraticBezierTo(259, 163, 244, 133)
      ..close();
    canvas.drawPath(beak, Paint()..color = gold);
    final smile = Path()
      ..moveTo(250, 137)
      ..quadraticBezierTo(260, 149, 270, 138);
    canvas.drawPath(
      smile,
      Paint()
        ..color = navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BirdPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
