import 'template_customization.dart';

enum MarkStyle { clock, compact, badge, sheet, inspection, simple }

enum MarkTemplate {
  classic('Time & Location', MarkStyle.clock, 0xFFFFCB30),
  custom('Custom Text', MarkStyle.compact, 0xFFFFCB30),
  clockIn('Clock in', MarkStyle.badge, 0xFFFFCB30),
  security('Security Patrol', MarkStyle.badge, 0xFF4155BD),
  completed('Completed', MarkStyle.badge, 0xFF713B2B),
  inspection('Inspection', MarkStyle.inspection, 0xFFFF7738),
  express('Express', MarkStyle.badge, 0xFFED2637),
  sheet('Sheet', MarkStyle.sheet, 0xFF66BE93),
  cleaned('Cleaned', MarkStyle.badge, 0xFF209CC5),
  project('Project', MarkStyle.sheet, 0xFFD49337),
  weather('Location & Weather', MarkStyle.inspection, 0xFFFFCB30),
  construction('Construction Record', MarkStyle.sheet, 0xFF394AA4),
  visit('Visit Report', MarkStyle.compact, 0xFFFFCB30),
  portrait('Portrait', MarkStyle.clock, 0xFFFFCB30),
  timeProof('TimeProof', MarkStyle.badge, 0xFF1977BD),
  map('Map', MarkStyle.compact, 0xFF249CE4),
  activity('Activity Record', MarkStyle.badge, 0xFF12B94D),
  service('Service', MarkStyle.compact, 0xFFFFCB30),
  report('Work Report', MarkStyle.sheet, 0xFFD49337),
  services('Services', MarkStyle.badge, 0xFF19B55A),
  simple('Simple style', MarkStyle.simple, 0xFFFFCB30),
  hkjaya('HK & JAYA', MarkStyle.sheet, 0xFF394AA4),
  kfc('KFC', MarkStyle.badge, 0xFFFF1429),
  qmb('QMB', MarkStyle.badge, 0xFFFFCB30),
  indomaret('Indomaret', MarkStyle.clock, 0xFFFFCB30),
  aice('Aice', MarkStyle.badge, 0xFFFFCB30),
  oppo('OPPO', MarkStyle.clock, 0xFF13A85D),
  spx('SPX Express', MarkStyle.badge, 0xFFFFCB30),
  pln('PLN', MarkStyle.badge, 0xFFCDDF39),
  kai('KAI', MarkStyle.inspection, 0xFFFFCB30),
  g4s('G4S Security', MarkStyle.badge, 0xFF394AA4),
  telkom('Telkom Akses', MarkStyle.clock, 0xFFED3D46),
  adhi('Adhi', MarkStyle.badge, 0xFFFFCB30),
  khongGuan('Khong Guan', MarkStyle.compact, 0xFFE52B31),
  indomie('Indomie', MarkStyle.compact, 0xFFFFCB30),
  tss('TSS', MarkStyle.badge, 0xFF209CC5),
  wahana('Wahana Express', MarkStyle.badge, 0xFFFFCB30),
  smartfren('Smartfren', MarkStyle.clock, 0xFFED3D46),
  jt('J&T Express', MarkStyle.badge, 0xFFFFCB30);

  bool get branded => index >= MarkTemplate.hkjaya.index;

  const MarkTemplate(this.label, this.style, this.color);
  final String label;
  final MarkStyle style;
  final int color;
}

enum WatermarkLayout {
  bottomLeft('Kiri bawah'),
  bottomRight('Kanan bawah'),
  footer('Banner footer');

  const WatermarkLayout(this.label);
  final String label;
}

class WatermarkData {
  const WatermarkData({
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.address = 'Lokasi belum tersedia',
    this.layout = WatermarkLayout.bottomLeft,
    this.isManual = false,
    this.photoCode = '7KWM9PXRTN6MTC',
    this.template = MarkTemplate.classic,
    this.enabled = true,
    this.isEdited = false,
    this.customization = const TemplateCustomization(),
  });

  final TemplateCustomization customization;
  final bool isEdited;
  final MarkTemplate template;
  final bool enabled;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String address;
  final WatermarkLayout layout;
  final bool isManual;
  final String photoCode;

  WatermarkData copyWith({
    MarkTemplate? template,
    TemplateCustomization? customization,
    bool? enabled,
  }) => WatermarkData(
    capturedAt: capturedAt,
    latitude: latitude,
    longitude: longitude,
    address: address,
    layout: layout,
    isManual: isManual,
    isEdited: isEdited,
    photoCode: photoCode,
    template: template ?? this.template,
    enabled: enabled ?? this.enabled,
    customization: customization ?? this.customization,
  );

  String get clock =>
      '${capturedAt.hour.toString().padLeft(2, '0')}:'
      '${capturedAt.minute.toString().padLeft(2, '0')}';
  String get longDate {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${capturedAt.day} ${months[capturedAt.month - 1]} ${capturedAt.year}';
  }

  String get weekday => const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ][capturedAt.weekday - 1];

  String get timestamp {
    String pad(int value) => value.toString().padLeft(2, '0');
    final d = capturedAt;
    return '${pad(d.day)}/${pad(d.month)}/${d.year} - '
        '${pad(d.hour)}:${pad(d.minute)}:${pad(d.second)}';
  }

  String get numericDate {
    final d = capturedAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get shortMonthDay =>
      '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][capturedAt.month - 1]} ${capturedAt.day}';
  String get compassCoordinates => latitude == null || longitude == null
      ? 'GPS tidak tersedia'
      : '${latitude!.abs().toStringAsFixed(6)}°${latitude! < 0 ? "S" : "N"}, ${longitude!.abs().toStringAsFixed(6)}°${longitude! < 0 ? "W" : "E"}';

  String get coordinates => latitude == null || longitude == null
      ? 'GPS tidak tersedia'
      : '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
}
