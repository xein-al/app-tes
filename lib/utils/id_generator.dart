import 'dart:math';

/// Simple collision-safe ID generator tanpa dependency eksternal.
/// Kombinasi timestamp + counter + random untuk guarantee uniqueness.
class IdGenerator {
  static int _counter = 0;
  static int _lastTimestamp = 0;

  /// Generate ID yang collision-safe untuk batch insert.
  /// Format: {timestamp}_{counter}_{random}
  static String generate() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Reset counter jika timestamp berubah
    if (now != _lastTimestamp) {
      _counter = 0;
      _lastTimestamp = now;
    }

    _counter++;
    final random = Random().nextInt(999999);

    return '${now}_${_counter}_$random';
  }
}
