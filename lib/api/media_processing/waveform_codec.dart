import 'media_processing_backend.dart';

/// 웨이브폼 샘플링·인코딩·파싱 규칙을 한곳에 모아 호출부 중복을 제거합니다.
class WaveformCodec {
  const WaveformCodec({
    /// 백엔드 구현체를 주입받을 수 있도록 설계하여, 테스트 시점에 모킹이나 대체 구현체로 교체할 수 있게 합니다.
    MediaProcessingBackend backend = DefaultMediaProcessingBackend.instance,
  }) : _backend = backend;

  /// 실제 인코딩/디코딩 로직을 담당하는 백엔드 구현체입니다.
  final MediaProcessingBackend _backend;

  /// 서버 전송용 웨이브폼을 필요 샘플 수와 포맷에 맞춰 null-safe 하게 인코딩하여 반환하는 메소드.
  ///
  /// 인코딩이란?
  /// - 원본 웨이브폼 데이터를 최대 maxSamples 개로 샘플링하고,
  ///   소수점 decimals 자리까지 반올림한 후,
  ///   지정된 format으로 직렬화하는 과정을 말합니다.
  ///
  /// Parameters:
  /// - [waveformData]: 원본 웨이브폼 데이터 리스트입니다.
  /// - [maxSamples]: 인코딩된 웨이브폼이 가질 최대 샘플 수입니다. 원본 데이터가 이보다 많으면 샘플링이 수행됩니다.
  /// - [decimals]: 각 샘플 값을 반올림할 소수점 자리 수입니다. 기본값은 4입니다.
  /// - [format]: 인코딩된 웨이브폼의 직렬화 포맷입니다. 기본값은 JSON입니다.
  ///
  /// Returns:
  /// - [String?]: 인코딩된 웨이브폼 문자열을 반환.
  /// - [null]: 입력 데이터가 null이거나 비어있으면 null을 반환합니다.
  String? encodeOrNull(
    List<double>? waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  }) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }

    // media_processing_backend의 encodeWaveform을 호출하여 인코딩된 문자열을 받아옵니다.
    // 이때, maxSamples, decimals, format 등의 파라미터도 함께 전달합니다.
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

  /// 화면 표시용 웨이브폼을 항상 문자열 형태로 인코딩하여 반환하는 메소드.
  /// - encodeOrNull과 동일한 인코딩 로직을 사용하지만, null 대신 빈 문자열을 반환합니다.
  ///
  /// Parameters:
  /// - [waveformData]: 원본 웨이브폼 데이터 리스트입니다.
  /// - [maxSamples]: 인코딩된 웨이브폼이 가질 최대 샘플 수입니다. 원본 데이터가 이보다 많으면 샘플링이 수행됩니다.
  /// - [decimals]: 각 샘플 값을 반올림할 소수점 자리 수입니다. 기본값은 4입니다.
  /// - [format]: 인코딩된 웨이브폼의 직렬화 포맷입니다. 기본값은 JSON입니다.
  ///
  /// Returns:
  /// - [String]: 인코딩된 웨이브폼 문자열을 반환.
  /// - [' ']: 입력 데이터가 null이거나 비어있으면 빈 문자열을 반환합니다.
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

  /// 서버에서 받은 웨이브폼 문자열을 복원하여 리스트 형태로 반환하는 메소드.
  /// 디코딩이란?
  /// - 서버에서 받은 웨이브폼 문자열을 지정된 format으로 변환하여 원본 웨이브폼 데이터 리스트로 복원하는 과정을 말합니다
  ///
  /// Parameters:
  /// - [waveformString]: 서버에서 받은 웨이브폼 **문자열**입니다.
  ///
  /// Returns:
  /// - [List<[double]>]: 복원된 웨이브폼 데이터 리스트를 반환.
  /// - [null]: 입력 문자열이 null이거나 비어있으면 null을 반환합니다.
  List<double>? decodeOrNull(String? waveformString) {
    // media_processing_backend의 decodeWaveform을 호출하여 리스트로 복원된 웨이브폼 데이터를 받아옵니다.
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
