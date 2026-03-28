import 'package:flutter_test/flutter_test.dart';
import 'package:soi/views/common_widget/api_photo/services/api_photo_waveform_parser_service.dart';

void main() {
  group('ApiPhotoWaveformParserService', () {
    test('parses JSON waveform payloads', () {
      final parsed = ApiPhotoWaveformParserService.parse('[0.1,0.2,0.3]');

      expect(parsed, <double>[0.1, 0.2, 0.3]);
    });

    test('parses CSV waveform payloads as a fallback', () {
      final parsed = ApiPhotoWaveformParserService.parse('0.1, 0.2, 0.3');

      expect(parsed, <double>[0.1, 0.2, 0.3]);
    });
  });
}
