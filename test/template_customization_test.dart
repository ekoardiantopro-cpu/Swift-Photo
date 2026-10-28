import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_photo/models/template_customization.dart';

void main() {
  test(
    'Logo stays in bounds on phones/tablets and preserves normalized placement',
    () {
      for (final size in [
        const Size(320, 568),
        const Size(768, 1024),
        const Size(1024, 768),
      ]) {
        final rect = const TemplateCustomization(
          logoX: .99,
          logoY: .99,
          logoWidth: .6,
        ).logoRect(size, 3);
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
      }
      final a = const TemplateCustomization(
        logoX: .2,
        logoY: .3,
      ).logoRect(const Size(320, 568), 3);
      final b = const TemplateCustomization(
        logoX: .2,
        logoY: .3,
      ).logoRect(const Size(640, 1136), 3);
      expect(
        b,
        Rect.fromLTWH(a.left * 2, a.top * 2, a.width * 2, a.height * 2),
      );
      expect(const TemplateCustomization().logoRect(Size.zero, 0), Rect.zero);
    },
  );
  test('Invalid saved values fall back or clamp safely', () {
    final config = TemplateCustomization.fromJson({
      'logoX': double.nan,
      'logoY': double.infinity,
      'logoWidth': 8,
      'logoOpacity': -.5,
      'logoRadius': 9,
      'showCode': false,
    });
    expect(config.logoX, .05);
    expect(config.logoY, .60);
    expect(config.logoWidth, .65);
    expect(config.logoOpacity, .1);
    expect(config.logoRadius, .5);
    expect(config.showCode, isFalse);
    expect(
      TemplateCustomization.fromJson(config.toJson()).toJson(),
      config.toJson(),
    );
  });
}
