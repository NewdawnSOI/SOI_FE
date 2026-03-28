import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:soi_media_native/soi_media_native.dart' as native;
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 공통 이미지 출력 포맷을 정의해 앱과 네이티브 패키지 사이 계약을 고정합니다.
enum MediaImageOutputFormat { webp, jpeg, png }

/// 공통 썸네일 포맷을 정의해 캐시와 생성 경로가 같은 기준을 쓰게 합니다.
enum MediaThumbnailFormat { jpeg, webp, png }

/// 공통 비디오 품질 프리셋을 정의해 서비스가 구현 상세를 몰라도 되게 합니다.
enum MediaVideoQualityPreset { res1280x720, medium, low }

/// 웨이브폼 전송 포맷을 명시해 JSON과 CSV 경로를 같은 코덱에서 제어합니다.
enum WaveformTransportFormat { json, csv }

/// 이미지 메타데이터를 전달해 aspect ratio 계산을 공통 결과로 재사용합니다.
class MediaImageProbeResult {
  const MediaImageProbeResult({required this.width, required this.height});

  final int width;
  final int height;

  double? get aspectRatio {
    if (height == 0) {
      return null;
    }
    return width / height;
  }
}

/// Flutter 코드가 미디어 처리를 호출할 때 지켜야 하는 단일 계약입니다.
/// 네이티브 패키지와 플랫폼 플러그인에서 구현한 기능을 한곳에 모아 앱 레이어가 구체적인 구현을 몰라도 되게 합니다.
///
/// 추상 클래스로 각 메소드를 정의해 앱 레이어가 기대하는 기능과 입력/출력 형식을 명확히 합니다.
abstract interface class MediaProcessingBackend {
  /// 이미지 크기를 읽어 화면 레이어가 직접 decoder 구현을 알지 않게 합니다.
  Future<MediaImageProbeResult?> probeImage(File file);

  /// **이미지 압축**을 공통 진입점으로 모아 서비스별 정책만 남기도록 합니다.
  /// 기본적으로 네이티브 패키지에 위임.
  Future<File?> compressImage({
    required File inputFile,
    required String outputPath,
    required int quality,
    required int minWidth,
    required int minHeight,
    MediaImageOutputFormat format = MediaImageOutputFormat.webp,
  });

  /// **비디오 변환**을 공통 품질 enum으로 감싸 플랫폼 상세 의존성을 줄입니다.
  /// 기본적으로 Flutter 비디오 압축 패키지에 위임.
  Future<File?> transcodeVideo({
    required File inputFile,
    required MediaVideoQualityPreset qualityPreset,
    bool includeAudio = true,
  });

  /// 파일 기반 썸네일 생성을 공통 계약으로 묶어 업로드와 대표 이미지 흐름을 공유합니다.
  /// 기본적으로 video_thumbnail 패키지(Flutter 패키지)에 위임.
  Future<File?> generateThumbnail({
    required String videoPath,
    String? outputPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.webp,
    int maxWidth = 720,
    int maxHeight = 0,
    int quality = 80,
  });

  /// 바이트 기반 썸네일 생성을 공통 계약으로 묶어 캐시 계층에서 재사용합니다.
  Future<Uint8List?> generateThumbnailData({
    required String videoPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.jpeg,
    int maxWidth = 262,
    int maxHeight = 0,
    int quality = 75,
  });

  /// 웨이브폼 샘플링 규칙을 한 군데에서 관리해 호출부마다 편차가 생기지 않게 합니다.
  List<double> sampleWaveform(List<double> source, int maxLength);

  /// 웨이브폼 문자열 인코딩을 한 계약으로 통일해 업로드 포맷을 안정적으로 유지합니다.
  String encodeWaveform(
    List<double> waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  });

  /// 웨이브폼 문자열 디코딩을 한 계약으로 통일해 JSON과 CSV fallback을 재사용합니다.
  List<double> decodeWaveform(String? waveformString);
}

/// 앱용 기본 구현은 네이티브 패키지와 Flutter 비디오 플러그인을 한곳에서 조합합니다.
/// 미디어 처리 로직이 앱과 패키지 사이에 흩어지지 않고 이 클래스 하나에 모이도록 해 유지보수를 쉽게 합니다.
final class DefaultMediaProcessingBackend implements MediaProcessingBackend {
  /// 네이티브 클라이언트를 주입할 수 있게 해 테스트에서 목API를 활용할 수 있도록 합니다.
  const DefaultMediaProcessingBackend({
    native.SoiMediaNativeClient client = const native.SoiMediaNativeClient(),
  }) : _client = client;

  /// 싱글톤 인스턴스를 제공해 앱 전체에서 같은 네이티브 클라이언트를 공유하게 합니다.
  static const DefaultMediaProcessingBackend instance =
      DefaultMediaProcessingBackend();

  /// 네이티브 패키지에 위임하는 기능은 네이티브 클라이언트를 통해 호출해 앱과 패키지 사이 의존성을 명확히 합니다.
  /// SoiMediaNativeClient는 FFI로 구현된 네이티브 기능을 감싸 앱 레이어가 직접 FFI를 알 필요 없게 합니다.
  final native.SoiMediaNativeClient _client;

  /// 이미지 probe는 native fast path를 먼저 시도하고, 실패하면 Flutter codec으로 fallback합니다.
  @override
  Future<MediaImageProbeResult?> probeImage(File file) async {
    final nativeResult = await _client.probeImage(file.path);
    if (nativeResult != null) {
      return MediaImageProbeResult(
        width: nativeResult.width,
        height: nativeResult.height,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final result = MediaImageProbeResult(
        width: image.width,
        height: image.height,
      );

      image.dispose();
      codec.dispose();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 이미지 압축은 FFI 패키지에 위임해 앱 전체가 같은 native 경로를 공유하게 합니다.
  @override
  Future<File?> compressImage({
    required File inputFile,
    required String outputPath,
    required int quality,
    required int minWidth,
    required int minHeight,
    MediaImageOutputFormat format = MediaImageOutputFormat.webp,
  }) {
    return _client.compressImage(
      inputPath: inputFile.absolute.path,
      outputPath: outputPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: switch (format) {
        MediaImageOutputFormat.webp => native.SoiImageOutputFormat.webp,
        MediaImageOutputFormat.jpeg => native.SoiImageOutputFormat.jpeg,
        MediaImageOutputFormat.png => native.SoiImageOutputFormat.png,
      },
    );
  }

  /// 비디오 압축은 아직 플랫폼 플러그인이 더 안정적이라 앱 레이어에서 직접 유지합니다.
  @override
  Future<File?> transcodeVideo({
    required File inputFile,
    required MediaVideoQualityPreset qualityPreset,
    bool includeAudio = true,
  }) async {
    final info = await VideoCompress.compressVideo(
      inputFile.path,
      quality: switch (qualityPreset) {
        MediaVideoQualityPreset.res1280x720 => VideoQuality.Res1280x720Quality,
        MediaVideoQualityPreset.medium => VideoQuality.MediumQuality,
        MediaVideoQualityPreset.low => VideoQuality.LowQuality,
      },
      includeAudio: includeAudio,
      deleteOrigin: false,
    );
    return info?.file;
  }

  /// 파일 썸네일은 video_thumbnail을 한곳에서 감싸 캐시와 업로드 흐름이 같은 API를 쓰게 합니다.
  @override
  Future<File?> generateThumbnail({
    required String videoPath,
    String? outputPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.webp,
    int maxWidth = 720,
    int maxHeight = 0,
    int quality = 80,
  }) async {
    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: outputPath,
      imageFormat: switch (format) {
        MediaThumbnailFormat.jpeg => ImageFormat.JPEG,
        MediaThumbnailFormat.webp => ImageFormat.WEBP,
        MediaThumbnailFormat.png => ImageFormat.PNG,
      },
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
    if (thumbnailPath == null || thumbnailPath.isEmpty) {
      return null;
    }
    return File(thumbnailPath);
  }

  /// 메모리 캐시용 썸네일 바이트는 video_thumbnail을 감싸 한곳에서만 생성합니다.
  @override
  Future<Uint8List?> generateThumbnailData({
    required String videoPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.jpeg,
    int maxWidth = 262,
    int maxHeight = 0,
    int quality = 75,
  }) {
    return VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: switch (format) {
        MediaThumbnailFormat.jpeg => ImageFormat.JPEG,
        MediaThumbnailFormat.webp => ImageFormat.WEBP,
        MediaThumbnailFormat.png => ImageFormat.PNG,
      },
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }

  /// 웨이브폼 샘플링은 native 구현을 그대로 사용해 앱 로직 중복을 없앱니다.
  @override
  List<double> sampleWaveform(List<double> source, int maxLength) {
    return _client.sampleWaveform(source, maxLength);
  }

  /// 웨이브폼 인코딩은 패키지 규칙을 재사용해 댓글과 업로드 포맷을 맞춥니다.
  @override
  String encodeWaveform(
    List<double> waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  }) {
    return _client.encodeWaveform(
      waveformData,
      maxSamples: maxSamples,
      decimals: decimals,
      format: switch (format) {
        WaveformTransportFormat.json => native.SoiWaveformEncodingFormat.json,
        WaveformTransportFormat.csv => native.SoiWaveformEncodingFormat.csv,
      },
    );
  }

  /// 웨이브폼 디코딩은 패키지 파서를 재사용해 JSON과 CSV fallback을 공통화합니다.
  @override
  List<double> decodeWaveform(String? waveformString) {
    return _client.decodeWaveform(waveformString);
  }
}
