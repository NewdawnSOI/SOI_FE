import '../../../../api/media_processing/waveform_codec.dart';

/// API photo 오디오 UI가 쓰는 웨이브폼 파싱 규칙을 공통 코덱에 위임합니다.
class ApiPhotoWaveformParserService {
  const ApiPhotoWaveformParserService._();

  static final WaveformCodec _waveformCodec = WaveformCodec();

  /// JSON/CSV 웨이브폼 문자열을 화면 표시용 리스트로 복원합니다.
  static List<double>? parse(String? waveformString) {
    return _waveformCodec.decodeOrNull(waveformString);
  }
}
