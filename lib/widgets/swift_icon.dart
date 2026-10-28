import 'package:flutter/material.dart';

enum SwiftGlyph {
  menu,
  flashOff,
  flashAuto,
  flashOn,
  switchCamera,
  camera,
  folder,
  edit,
  ratio,
  chevronDown,
  chevronRight,
  close,
}

/// Small vector icons share a 24 px grid and the same rounded outline weight.
class SwiftIcon extends StatelessWidget {
  const SwiftIcon(this.glyph, {super.key, this.size = 24, this.color});
  final SwiftGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _SwiftIconPainter(
        glyph,
        color ??
            const Color(
              0xFF252724,
            ).withValues(alpha: IconTheme.of(context).color?.a ?? 1),
      ),
    ),
  );
}

class _SwiftIconPainter extends CustomPainter {
  const _SwiftIconPainter(this.glyph, this.color);
  final SwiftGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), pen);
    switch (glyph) {
      case SwiftGlyph.menu:
        line(3, 5, 21, 5);
        line(3, 12, 17, 12);
        line(3, 19, 13, 19);
      case SwiftGlyph.flashOff:
      case SwiftGlyph.flashAuto:
      case SwiftGlyph.flashOn:
        canvas.drawPath(
          Path()
            ..moveTo(13, 2)
            ..lineTo(6, 13)
            ..lineTo(11, 13)
            ..lineTo(10, 22)
            ..lineTo(19, 10)
            ..lineTo(13, 10)
            ..lineTo(15, 2)
            ..close(),
          pen,
        );
        if (glyph == SwiftGlyph.flashOff) {
          canvas.drawLine(
            const Offset(3, 3),
            const Offset(21, 21),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 4.2
              ..strokeCap = StrokeCap.round,
          );
          line(3, 3, 21, 21);
        }
        if (glyph == SwiftGlyph.flashAuto) {
          canvas.drawRect(
            const Rect.fromLTWH(16, 0, 8, 9),
            Paint()..color = Colors.white,
          );
          final thin = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
          canvas.drawPath(
            Path()
              ..moveTo(17, 7)
              ..lineTo(19.5, 1)
              ..lineTo(22, 7)
              ..moveTo(18, 5)
              ..lineTo(21, 5),
            thin,
          );
        }
      case SwiftGlyph.switchCamera:
        canvas.drawPath(
          Path()
            ..moveTo(11, 4)
            ..lineTo(6, 4)
            ..quadraticBezierTo(2, 4, 2, 8)
            ..lineTo(2, 16)
            ..quadraticBezierTo(2, 20, 6, 20)
            ..lineTo(8, 20)
            ..moveTo(13, 20)
            ..lineTo(18, 20)
            ..quadraticBezierTo(22, 20, 22, 16)
            ..lineTo(22, 8)
            ..quadraticBezierTo(22, 4, 18, 4)
            ..lineTo(16, 4)
            ..moveTo(18, 1)
            ..lineTo(15, 4)
            ..lineTo(18, 7)
            ..moveTo(6, 17)
            ..lineTo(9, 20)
            ..lineTo(6, 23),
          pen,
        );
        canvas.drawCircle(const Offset(12, 12), 3.2, pen);
      case SwiftGlyph.camera:
        canvas.drawPath(
          Path()
            ..moveTo(3, 7)
            ..lineTo(7, 7)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(17, 7)
            ..lineTo(21, 7)
            ..quadraticBezierTo(22, 7, 22, 9)
            ..lineTo(22, 19)
            ..quadraticBezierTo(22, 21, 20, 21)
            ..lineTo(4, 21)
            ..quadraticBezierTo(2, 21, 2, 19)
            ..lineTo(2, 9)
            ..quadraticBezierTo(2, 7, 3, 7)
            ..close(),
          pen,
        );
        canvas.drawCircle(const Offset(12, 13.5), 4, pen);
      case SwiftGlyph.folder:
        canvas.drawPath(
          Path()
            ..moveTo(3, 6)
            ..quadraticBezierTo(3, 4, 5, 4)
            ..lineTo(10, 4)
            ..lineTo(12, 7)
            ..lineTo(20, 7)
            ..quadraticBezierTo(22, 7, 22, 9)
            ..lineTo(22, 19)
            ..quadraticBezierTo(22, 21, 20, 21)
            ..lineTo(5, 21)
            ..quadraticBezierTo(3, 21, 3, 19)
            ..lineTo(3, 17),
          pen,
        );
        line(1, 12, 12, 12);
        line(9, 9, 12, 12);
        line(9, 15, 12, 12);
      case SwiftGlyph.edit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 2, 16, 20),
            const Radius.circular(2.5),
          ),
          pen,
        );
        line(8, 12, 16, 12);
        line(8, 16, 16, 16);
        line(8, 19, 13, 19);
      case SwiftGlyph.ratio:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 4, 20, 16),
            const Radius.circular(2),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6, 11)
            ..lineTo(6, 8)
            ..lineTo(10, 8)
            ..moveTo(14, 16)
            ..lineTo(18, 16)
            ..lineTo(18, 13),
          pen,
        );
      case SwiftGlyph.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..lineTo(12, 15)
            ..lineTo(18, 9),
          pen,
        );
      case SwiftGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9, 6)
            ..lineTo(15, 12)
            ..lineTo(9, 18),
          pen,
        );
      case SwiftGlyph.close:
        line(5, 5, 19, 19);
        line(19, 5, 5, 19);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SwiftIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
