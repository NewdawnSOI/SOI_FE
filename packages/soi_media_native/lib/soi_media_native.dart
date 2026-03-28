import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'soi_media_native_bindings_generated.dart' as bindings;

enum SoiImageOutputFormat { webp, jpeg, png }

enum SoiWaveformEncodingFormat { json, csv }

/// 이미지 크기와 aspect ratio 계산에 필요한 메타데이터를 전달합니다.
class SoiImageProbeResult {
  const SoiImageProbeResult({required this.width, required this.height});

  final int width;
  final int height;

  double get aspectRatio => height == 0 ? 0 : width / height;
}

/// 패키지 API를 한 객체에 모아 테스트와 앱 통합에서 같은 계약을 재사용합니다.
class SoiMediaNativeClient {
  const SoiMediaNativeClient();

  /// probeImage는 짧은 FFI 호출로 이미지 크기를 읽어 aspect ratio 계산 비용을 줄입니다.
  Future<SoiImageProbeResult?> probeImage(String path) async {
    final nativePath = path.toNativeUtf8();
    final width = calloc<ffi.Int32>();
    final height = calloc<ffi.Int32>();
    try {
      final ok =
          bindings.soi_probe_image(nativePath.cast(), width, height) == 1;
      if (!ok || width.value <= 0 || height.value <= 0) {
        return null;
      }
      return SoiImageProbeResult(width: width.value, height: height.value);
    } finally {
      calloc.free(nativePath);
      calloc.free(width);
      calloc.free(height);
    }
  }

  /// compressImage는 decode-resize-encode 파이프라인을 native core 한 번으로 실행합니다.
  Future<File?> compressImage({
    required String inputPath,
    required String outputPath,
    required int quality,
    required int minWidth,
    required int minHeight,
    SoiImageOutputFormat format = SoiImageOutputFormat.webp,
  }) async {
    final ok = _compressImageSync(
      inputPath: inputPath,
      outputPath: outputPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: format,
    );
    if (!ok) {
      return null;
    }
    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      return null;
    }
    return outputFile;
  }

  /// sampleWaveform는 짧은 C 루프로 균일 샘플링을 수행해 Dart 측 할당과 반복문 비용을 줄입니다.
  List<double> sampleWaveform(List<double> source, int maxLength) {
    if (source.isEmpty || maxLength <= 0 || source.length <= maxLength) {
      return List<double>.from(source);
    }

    final input = calloc<ffi.Double>(source.length);
    final output = calloc<ffi.Double>(maxLength);
    try {
      for (var i = 0; i < source.length; i++) {
        input[i] = source[i];
      }

      final outputLength = bindings.soi_sample_waveform(
        input,
        source.length,
        maxLength,
        output,
      );
      if (outputLength <= 0) {
        return List<double>.from(source.take(maxLength));
      }

      return List<double>.generate(outputLength, (index) => output[index]);
    } finally {
      calloc.free(input);
      calloc.free(output);
    }
  }

  /// encodeWaveform는 샘플링과 반올림 규칙을 묶어 댓글/포스트 업로드 형식을 일관되게 만듭니다.
  String encodeWaveform(
    List<double> waveformData, {
    required int maxSamples,
    int decimals = 4,
    SoiWaveformEncodingFormat format = SoiWaveformEncodingFormat.json,
  }) {
    if (waveformData.isEmpty) {
      return '';
    }

    final sampled = sampleWaveform(waveformData, maxSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(decimals)))
        .toList(growable: false);

    return switch (format) {
      SoiWaveformEncodingFormat.json =>
        '[${rounded.map((value) => value.toString()).join(',')}]',
      SoiWaveformEncodingFormat.csv =>
        rounded.map((value) => value.toString()).join(','),
    };
  }

  /// decodeWaveform는 JSON 배열과 CSV 문자열 모두를 지원해 기존 서버 응답과 호환됩니다.
  List<double> decodeWaveform(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return const <double>[];
    }

    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) {
      return const <double>[];
    }

    final normalized = trimmed
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(RegExp(r'[,\s]+'))
        .where((part) => part.isNotEmpty);

    final values = <double>[];
    for (final part in normalized) {
      final parsed = double.tryParse(part);
      if (parsed != null) {
        values.add(parsed);
      }
    }
    return values;
  }
}

const SoiMediaNativeClient _defaultClient = SoiMediaNativeClient();

/// C 압축 엔트리포인트를 감싸 파일 경로와 enum 값을 native ABI에 맞게 넘깁니다.
bool _compressImageSync({
  required String inputPath,
  required String outputPath,
  required int quality,
  required int minWidth,
  required int minHeight,
  required SoiImageOutputFormat format,
}) {
  final nativeInputPath = inputPath.toNativeUtf8();
  final nativeOutputPath = outputPath.toNativeUtf8();
  try {
    return bindings.soi_compress_image(
          nativeInputPath.cast(),
          nativeOutputPath.cast(),
          quality,
          minWidth,
          minHeight,
          format.index,
        ) ==
        1;
  } finally {
    calloc.free(nativeInputPath);
    calloc.free(nativeOutputPath);
  }
}

Future<SoiImageProbeResult?> probeImage(String path) =>
    _defaultClient.probeImage(path);

Future<File?> compressImage({
  required String inputPath,
  required String outputPath,
  required int quality,
  required int minWidth,
  required int minHeight,
  SoiImageOutputFormat format = SoiImageOutputFormat.webp,
}) => _defaultClient.compressImage(
  inputPath: inputPath,
  outputPath: outputPath,
  quality: quality,
  minWidth: minWidth,
  minHeight: minHeight,
  format: format,
);

List<double> sampleWaveform(List<double> source, int maxLength) =>
    _defaultClient.sampleWaveform(source, maxLength);

String encodeWaveform(
  List<double> waveformData, {
  required int maxSamples,
  int decimals = 4,
  SoiWaveformEncodingFormat format = SoiWaveformEncodingFormat.json,
}) => _defaultClient.encodeWaveform(
  waveformData,
  maxSamples: maxSamples,
  decimals: decimals,
  format: format,
);

List<double> decodeWaveform(String? waveformString) =>
    _defaultClient.decodeWaveform(waveformString);
