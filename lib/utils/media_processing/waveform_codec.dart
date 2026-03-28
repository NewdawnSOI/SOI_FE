import 'media_processing_backend.dart';

/// 웨이브폼 샘플링·인코딩·파싱 규칙을 한곳에 모아 호출부 중복을 제거합니다.
class WaveformCodec {
  const WaveformCodec({
    MediaProcessingBackend backend = DefaultMediaProcessingBackend.instance,
  }) : _backend = backend;

  final MediaProcessingBackend _backend;

  /// 서버 전송용 웨이브폼을 필요 샘플 수와 포맷에 맞춰 null-safe 하게 인코딩합니다.
  String? encodeOrNull(
    List<double>? waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  }) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }

    final encoded = _backend.encodeWaveform(
      waveformData,
      maxSamples: maxSamples,
      decimals: decimals,
      format: format,
    );
    if (encoded.isEmpty) {
      return null;
    }
    return encoded;
  }

  /// 빈 문자열 계약이 필요한 호출부를 위해 null 대신 빈 값을 반환합니다.
  String encodeOrEmpty(
    List<double>? waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  }) {
    return encodeOrNull(
          waveformData,
          maxSamples: maxSamples,
          decimals: decimals,
          format: format,
        ) ??
        '';
  }

  /// 화면 표시용 웨이브폼을 빈 리스트 대신 null 허용 형태로 복원합니다.
  List<double>? decodeOrNull(String? waveformString) {
    final decoded = _backend.decodeWaveform(waveformString);
    if (decoded.isEmpty) {
      return null;
    }
    return decoded;
  }

  /// 화면 표시용 웨이브폼을 항상 리스트 형태로 복원합니다.
  List<double> decodeOrEmpty(String? waveformString) {
    return _backend.decodeWaveform(waveformString);
  }

  /// 호출부가 직접 샘플링해야 할 때도 같은 규칙을 재사용하게 합니다.
  List<double> sample(List<double> source, int maxLength) {
    return _backend.sampleWaveform(source, maxLength);
  }
}
