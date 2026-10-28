import 'dart:math';

class MediaFileNames {
  static List<String> editedCandidates(String original, {Random? random}) {
    if (original.contains('/') ||
        original.contains(r'\') ||
        !original.toLowerCase().endsWith('.png') ||
        original.length <= 4) {
      throw ArgumentError('Nama foto PNG tidak valid');
    }
    final stem = original.substring(0, original.length - 4);
    final extension = original.substring(original.length - 4);
    final suffixes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('')
      ..shuffle(random ?? Random.secure());
    return suffixes.map((suffix) => '$stem$suffix$extension').toList();
  }
}
