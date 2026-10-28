import 'dart:ui';

class TemplateCustomization {
  const TemplateCustomization({
    this.logoX = .05,
    this.logoY = .60,
    this.logoWidth = .30,
    this.logoOpacity = 1,
    this.logoRadius = 0,
    this.showLogo = true,
    this.showTime = true,
    this.showAddress = true,
    this.showCoordinates = true,
    this.showCode = true,
  });
  final double logoX, logoY, logoWidth, logoOpacity, logoRadius;
  final bool showLogo, showTime, showAddress, showCoordinates, showCode;

  Rect logoRect(Size size, double aspect) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      return Rect.zero;
    }
    final width = size.width * logoWidth.clamp(.08, .65);
    final height = (width / (aspect.isFinite && aspect > 0 ? aspect : 1)).clamp(
      0.0,
      size.height * .4,
    );
    return Rect.fromLTWH(
      (logoX * size.width).clamp(0.0, size.width - width),
      (logoY * size.height).clamp(0.0, size.height - height),
      width,
      height,
    );
  }

  TemplateCustomization copyWith({
    double? logoX,
    double? logoY,
    double? logoWidth,
    double? logoOpacity,
    double? logoRadius,
    bool? showLogo,
    bool? showTime,
    bool? showAddress,
    bool? showCoordinates,
    bool? showCode,
  }) => TemplateCustomization(
    logoX: logoX ?? this.logoX,
    logoY: logoY ?? this.logoY,
    logoWidth: logoWidth ?? this.logoWidth,
    logoOpacity: logoOpacity ?? this.logoOpacity,
    logoRadius: logoRadius ?? this.logoRadius,
    showLogo: showLogo ?? this.showLogo,
    showTime: showTime ?? this.showTime,
    showAddress: showAddress ?? this.showAddress,
    showCoordinates: showCoordinates ?? this.showCoordinates,
    showCode: showCode ?? this.showCode,
  );
  Map<String, dynamic> toJson() => {
    'logoX': logoX,
    'logoY': logoY,
    'logoWidth': logoWidth,
    'logoOpacity': logoOpacity,
    'logoRadius': logoRadius,
    'showLogo': showLogo,
    'showTime': showTime,
    'showAddress': showAddress,
    'showCoordinates': showCoordinates,
    'showCode': showCode,
  };
  factory TemplateCustomization.fromJson(dynamic value) {
    if (value is! Map) return const TemplateCustomization();
    double number(String key, double fallback, double min, double max) {
      final n = value[key];
      return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
    }

    return TemplateCustomization(
      logoX: number('logoX', .05, 0, 1),
      logoY: number('logoY', .60, 0, 1),
      logoWidth: number('logoWidth', .30, .08, .65),
      logoOpacity: number('logoOpacity', 1, .1, 1),
      logoRadius: number('logoRadius', 0, 0, .5),
      showLogo: value['showLogo'] != false,
      showTime: value['showTime'] != false,
      showAddress: value['showAddress'] != false,
      showCoordinates: value['showCoordinates'] != false,
      showCode: value['showCode'] != false,
    );
  }
}
