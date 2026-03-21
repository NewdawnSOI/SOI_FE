import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 업로드 관련 모델 정의
String _encodeWaveformDataWorker(List<double> waveformData) {
  if (waveformData.isEmpty) return '';

  final buffer = StringBuffer();
  for (var i = 0; i < waveformData.length; i++) {
    if (i > 0) buffer.write(', ');
    buffer.write(double.parse(waveformData[i].toStringAsFixed(6)).toString());
  }
  return buffer.toString();
}

class PhotoEditorMediaProcessingService {
  ///
  /// **사진 편집**과 관련된 **미디어 처리 서비스**를 제공하는 클래스입니다.
  /// 이미지 압축, 비디오 압축, 썸네일 추출, 파형 데이터 인코딩 등의 기능을 포함합니다.
  /// 이 서비스는 사진 편집 화면에서 사용되는 미디어 파일을 최적화하여 업로드할 수 있도록 도와줍니다.
  ///
  /// Parameters:
  /// - [_maxImageSizeBytes]: 이미지 파일의 최대 허용 크기 (바이트 단위)입니다. 기본값은 1MB입니다.
  /// - [_initialCompressionQuality]: 이미지 압축을 시작할 때 사용할 초기 품질 수준입니다. 기본값은 85입니다.
  /// - [_minCompressionQuality]: 이미지 압축에서 허용되는 최소 품질 수준입니다. 기본값은 40입니다.
  /// - [_qualityDecrement]: 이미지 압축 시 품질을 점진적으로 낮출 때 사용할 감소량입니다. 기본값은 10입니다.
  /// - [_initialImageDimension]: 이미지 압축을 시작할 때 사용할 초기 최대 가로/세로 길이입니다. 기본값은 2200입니다.
  /// - [_minImageDimension]: 이미지 압축에서 허용되는 최소 가로/세로 길이입니다. 기본값은 960입니다.
  /// - [_dimensionScaleFactor]: 이미지 압축 시 가로/세로 길이를 점진적으로 줄일 때 사용할 축소 비율입니다. 기본값은 0.85입니다.
  /// - [_fallbackCompressionQuality]: 최후의 수단으로 이미지 압축을 시도할 때 사용할 품질 수준입니다. 기본값은 35입니다.
  /// - [_fallbackImageDimension]: 최후의 수단으로 이미지 압축을 시도할 때 사용할 최대 가로/세로 길이입니다. 기본값은 1024입니다.
  /// - [_maxVideoSizeBytes]: 비디오 파일의 최대 허용 크기 (바이트 단위)입니다. 기본값은 50MB입니다.
  ///
  /// methods:
  /// - [calculateImageAspectRatio]
  ///   - 이미지 파일의 **가로세로 비율**을 계산하는 메서드입니다.
  ///   - 이미지 파일을 입력으로 받아 가로세로 비율을 반환합니다.
  ///   - 계산에 실패할 경우 null을 반환합니다.
  ///
  /// - [extractVideoThumbnailFile]
  ///   - 비디오 파일에서 썸네일 이미지를 추출하는 메서드입니다.
  ///   - 비디오 파일 경로를 입력으로 받아 **추출된 썸네일 이미지 파일**을 반환합니다.
  ///   - 썸네일 추출에 실패할 경우 null을 반환합니다.
  ///
  /// - [encodeWaveformDataAsync]
  ///   - 파형 데이터를 문자열로 인코딩하는 메서드입니다.
  ///   - 입력된 파형 데이터 리스트를 콤마로 구분된 문자열로 변환하여 반환합니다.
  ///   - 입력 데이터가 null이거나 비어있는 경우 null을 반환합니다.
  ///
  /// - [compressVideoIfNeeded]
  ///   - 비디오 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드입니다.
  ///   - 압축된 비디오 파일을 반환하며, 압축이 필요하지 않거나 압축에 실패할 경우 원본 파일을 반환합니다.
  ///
  /// - [compressImageIfNeeded]
  ///   - 이미지 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드입니다.
  ///   - 압축된 이미지 파일을 반환하며, 압축이 필요하지 않거나 압축에 실패할 경우 원본 파일을 반환합니다.
  ///
  /// - [_tryCompressVideo]
  ///   - 비디오 압축을 시도하는 메서드입니다.
  ///   - 지정된 품질로 비디오를 압축하며, 압축된 파일을 반환합니다.
  ///   - 압축에 실패할 경우 null을 반환합니다.
  ///
  /// - [_tryProgressiveCompression]
  ///   - 이미지 압축을 시도하는 메서드입니다.
  ///   - 초기 품질과 차원으로 압축을 시작하여, 필요에 따라 품질과 차원을 점진적으로 낮추며 압축을 시도합니다.
  ///   - 최적의 압축된 파일을 반환하며, 압축에 실패할 경우 null을 반환합니다.
  ///
  /// - [_tryFallbackCompression]
  ///   - 최후의 수단으로 더 낮은 품질과 작은 차원으로 이미지 압축을 시도하는 메서드입니다.
  ///   - 압축된 파일을 반환하며, 압축에 실패할 경우 null을 반환합니다.
  ///
  /// - [_compressWithSettings]
  ///   - 실제 이미지 압축을 수행하는 메서드입니다.
  ///   - 지정된 품질과 차원으로 이미지를 압축하며, 압축된 파일을 반환합니다.
  ///   - 압축에 실패할 경우 null을 반환합니다.
  ///
  /// - [_encodeWaveformData]
  ///   - 파형 데이터를 문자열로 인코딩하는 메서드입니다.
  ///   - 입력된 파형 데이터 리스트를 콤마로 구분된 문자열로 변환하여 반환합니다.
  ///   - 입력 데이터가 null이거나 비어있는 경우 null을 반환합니다.
  ///
  const PhotoEditorMediaProcessingService();

  static const int _maxImageSizeBytes = 1024 * 1024;
  static const int _initialCompressionQuality = 85;
  static const int _minCompressionQuality = 40;
  static const int _qualityDecrement = 10;
  static const int _initialImageDimension = 2200;
  static const int _minImageDimension = 960;
  static const double _dimensionScaleFactor = 0.85;
  static const int _fallbackCompressionQuality = 35;
  static const int _fallbackImageDimension = 1024;

  static const int _maxVideoSizeBytes = 50 * 1024 * 1024;

  /// 이미지의 가로세로 비율을 계산하는 메서드
  Future<double?> calculateImageAspectRatio(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();

      image.dispose();
      codec.dispose();

      if (height == 0) return null;
      return width / height;
    } catch (e) {
      debugPrint('[PhotoEditor] 이미지 aspect ratio 계산 실패: $e');
      return null;
    }
  }

  /// 비디오에서 썸네일 이미지를 추출하는 메서드
  Future<File?> extractVideoThumbnailFile(String videoPath) async {
    if (kIsWeb) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.WEBP,
        maxWidth: 720,
        quality: 80,
      );
      if (thumbnailPath == null || thumbnailPath.isEmpty) return null;
      return File(thumbnailPath);
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 썸네일 추출 실패: $e');
      return null;
    }
  }

  /// 파형 데이터를 문자열로 인코딩하는 메서드
  Future<String?> encodeWaveformDataAsync(List<double>? waveformData) async {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }

    if (kIsWeb || waveformData.length < 800) {
      return _encodeWaveformData(waveformData);
    }

    try {
      final encoded = await compute(_encodeWaveformDataWorker, waveformData);
      return encoded.isEmpty ? null : encoded;
    } catch (e) {
      debugPrint('[PhotoEditor] waveform encode isolate failed: $e');
      return _encodeWaveformData(waveformData);
    }
  }

  /// 비디오 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드
  Future<File> compressVideoIfNeeded(File file) async {
    if (kIsWeb) return file;

    final size = await file.length();
    if (size <= _maxVideoSizeBytes) {
      return file;
    }

    debugPrint('[PhotoEditor] 비디오 압축 필요: ${size ~/ 1024}KB');

    // 1단계: 720p 품질로 압축
    var compressed = await _tryCompressVideo(
      file,
      VideoQuality.Res1280x720Quality,
    );
    if (compressed != null) {
      final compressedSize = await compressed.length();
      debugPrint('[PhotoEditor] 1단계 압축 결과: ${compressedSize ~/ 1024}KB');
      if (compressedSize <= _maxVideoSizeBytes) return compressed;
    }

    // 2단계: 중간 품질로 압축
    compressed = await _tryCompressVideo(file, VideoQuality.MediumQuality);
    if (compressed != null) {
      final compressedSize = await compressed.length();
      debugPrint('[PhotoEditor] 2단계 압축 결과: ${compressedSize ~/ 1024}KB');
      if (compressedSize <= _maxVideoSizeBytes) return compressed;
    }

    // 3단계: 낮은 품질로 최종 압축 시도
    debugPrint('[PhotoEditor] 3단계: LowQuality 압축 시도');
    compressed = await _tryCompressVideo(file, VideoQuality.LowQuality);
    return compressed ?? file;
  }

  /// 이미지 파일이 최대 허용 크기를 초과하는 경우 압축하는 메서드
  Future<File> compressImageIfNeeded(File file) async {
    var currentSize = await file.length();
    if (currentSize <= _maxImageSizeBytes) {
      return file;
    }

    final compressedFile = await _tryProgressiveCompression(file); // 점진적 압축 시도
    if (compressedFile != null) {
      currentSize = await compressedFile.length();
      if (currentSize <= _maxImageSizeBytes) {
        return compressedFile;
      }
    }

    final fallbackFile = await _tryFallbackCompression(file); // 최후의 수단 압축 시도
    return fallbackFile ?? compressedFile ?? file;
  }

  /// 비디오 압축을 시도하는 메서드, 실패 시 null 반환
  Future<File?> _tryCompressVideo(File file, VideoQuality quality) async {
    try {
      final info = await VideoCompress.compressVideo(
        // 기본 설정으로 압축 시도
        file.path,
        quality: quality,
        includeAudio: true,
        deleteOrigin: false,
      );
      return info?.file;
    } catch (e) {
      debugPrint('[PhotoEditor] 비디오 압축 실패: $e');
      return null;
    }
  }

  /// 이미지 압축을 시도하는 메서드, 실패 시 null 반환
  Future<File?> _tryProgressiveCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    File? bestCompressed;
    var quality = _initialCompressionQuality;
    var dimension = _initialImageDimension;

    while (quality >= _minCompressionQuality) {
      final compressed = await _compressWithSettings(
        // 점진적 압축 시도
        file,
        tempDir,
        quality: quality,
        dimension: dimension,
        suffix: quality.toString(),
      );

      if (compressed == null) break;

      bestCompressed = compressed;
      final size = await compressed.length();
      if (size <= _maxImageSizeBytes) break;

      quality -= _qualityDecrement;
      dimension = math.max(
        (dimension * _dimensionScaleFactor).round(),
        _minImageDimension,
      );
    }

    return bestCompressed;
  }

  /// 최후의 수단으로 더 낮은 품질과 작은 차원으로 압축하는 메서드, 실패 시 null 반환
  /// 이 방법은 일반적인 압축 방법으로는 크기를 줄이지 못할 때 시도하는 마지막 단계입니다.
  ///
  /// Parameters:
  /// - [file]: 압축할 원본 이미지 파일
  ///
  /// Returns:
  /// - 압축된 이미지 파일 또는 null (압축 실패 시)
  Future<File?> _tryFallbackCompression(File file) async {
    final tempDir = await getTemporaryDirectory();
    return _compressWithSettings(
      file,
      tempDir,
      quality: _fallbackCompressionQuality,
      dimension: _fallbackImageDimension,
      suffix: 'force',
    );
  }

  /// 실제 이미지 압축을 수행하는 메서드, 실패 시 null 반환
  ///
  /// Parameters:
  /// - [file]: 압축할 원본 이미지 파일
  /// - [tempDir]: 압축된 파일을 저장할 임시 디렉토리
  /// - [quality]: 압축 품질 (0-100)
  /// - [dimension]: 압축 후 이미지의 최대 가로/세로 길이
  /// - [suffix]: 압축된 파일 이름에 붙일 접미사 (예: quality 수준)
  ///
  /// Returns:
  /// - 압축된 이미지 파일 또는 null (압축 실패 시)
  Future<File?> _compressWithSettings(
    File file,
    Directory tempDir, {
    required int quality,
    required int dimension,
    required String suffix,
  }) async {
    final targetPath = p.join(
      tempDir.path,
      'soi_upload_${DateTime.now().millisecondsSinceEpoch}_$suffix.webp',
    );

    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: dimension,
      minHeight: dimension,
      format: CompressFormat.webp,
    );

    return compressedXFile != null ? File(compressedXFile.path) : null;
  }

  /// 파형 데이터를 문자열로 인코딩하는 메서드, null 또는 빈 리스트인 경우 null 반환
  ///
  /// Parameters:
  /// - [waveformData]: 인코딩할 파형 데이터 리스트
  ///
  /// Returns:
  /// - 인코딩된 문자열 또는 null (입력 데이터가 null이거나 비어있는 경우)
  String? _encodeWaveformData(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return null;
    }
    final encoded = _encodeWaveformDataWorker(waveformData);
    return encoded.isEmpty ? null : encoded;
  }
}
