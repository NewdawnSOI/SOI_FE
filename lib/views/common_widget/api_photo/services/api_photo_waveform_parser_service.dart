import 'dart:convert';

class ApiPhotoWaveformParserService {
  const ApiPhotoWaveformParserService._();

  static List<double>? parse(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return null;
    }

    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((element) => (element as num).toDouble()).toList();
      }
    } catch (_) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      if (sanitized.isEmpty) return null;

      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);

      try {
        final values = parts.map((part) => double.parse(part)).toList();
        return values.isEmpty ? null : values;
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}
