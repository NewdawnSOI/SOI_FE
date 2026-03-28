import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:soi/api/media_processing/media_processing_backend.dart';

class FakeMediaProcessingBackend implements MediaProcessingBackend {
  FakeMediaProcessingBackend({
    this.onProbeImage,
    this.onCompressImage,
    this.onTranscodeVideo,
    this.onGenerateThumbnail,
    this.onGenerateThumbnailData,
    this.onSampleWaveform,
    this.onEncodeWaveform,
    this.onDecodeWaveform,
  });

  Future<MediaImageProbeResult?> Function(File file)? onProbeImage;
  Future<File?> Function({
    required File inputFile,
    required String outputPath,
    required int quality,
    required int minWidth,
    required int minHeight,
    required MediaImageOutputFormat format,
  })?
  onCompressImage;
  Future<File?> Function({
    required File inputFile,
    required MediaVideoQualityPreset qualityPreset,
    required bool includeAudio,
  })?
  onTranscodeVideo;
  Future<File?> Function({
    required String videoPath,
    required String? outputPath,
    required MediaThumbnailFormat format,
    required int maxWidth,
    required int maxHeight,
    required int quality,
  })?
  onGenerateThumbnail;
  Future<Uint8List?> Function({
    required String videoPath,
    required MediaThumbnailFormat format,
    required int maxWidth,
    required int maxHeight,
    required int quality,
  })?
  onGenerateThumbnailData;
  List<double> Function(List<double> source, int maxLength)? onSampleWaveform;
  String Function(
    List<double> waveformData, {
    required int maxSamples,
    required int decimals,
    required WaveformTransportFormat format,
  })?
  onEncodeWaveform;
  List<double> Function(String? waveformString)? onDecodeWaveform;

  int generateThumbnailDataCalls = 0;

  @override
  Future<MediaImageProbeResult?> probeImage(File file) async {
    return onProbeImage?.call(file);
  }

  @override
  Future<File?> compressImage({
    required File inputFile,
    required String outputPath,
    required int quality,
    required int minWidth,
    required int minHeight,
    MediaImageOutputFormat format = MediaImageOutputFormat.webp,
  }) async {
    return onCompressImage?.call(
      inputFile: inputFile,
      outputPath: outputPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: format,
    );
  }

  @override
  Future<File?> transcodeVideo({
    required File inputFile,
    required MediaVideoQualityPreset qualityPreset,
    bool includeAudio = true,
  }) async {
    return onTranscodeVideo?.call(
      inputFile: inputFile,
      qualityPreset: qualityPreset,
      includeAudio: includeAudio,
    );
  }

  @override
  Future<File?> generateThumbnail({
    required String videoPath,
    String? outputPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.webp,
    int maxWidth = 720,
    int maxHeight = 0,
    int quality = 80,
  }) async {
    return onGenerateThumbnail?.call(
      videoPath: videoPath,
      outputPath: outputPath,
      format: format,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }

  @override
  Future<Uint8List?> generateThumbnailData({
    required String videoPath,
    MediaThumbnailFormat format = MediaThumbnailFormat.jpeg,
    int maxWidth = 262,
    int maxHeight = 0,
    int quality = 75,
  }) async {
    generateThumbnailDataCalls += 1;
    return onGenerateThumbnailData?.call(
      videoPath: videoPath,
      format: format,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }

  @override
  List<double> sampleWaveform(List<double> source, int maxLength) {
    if (onSampleWaveform != null) {
      return onSampleWaveform!(source, maxLength);
    }
    if (source.length <= maxLength) {
      return List<double>.from(source);
    }
    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
      growable: false,
    );
  }

  @override
  String encodeWaveform(
    List<double> waveformData, {
    required int maxSamples,
    int decimals = 4,
    WaveformTransportFormat format = WaveformTransportFormat.json,
  }) {
    if (onEncodeWaveform != null) {
      return onEncodeWaveform!(
        waveformData,
        maxSamples: maxSamples,
        decimals: decimals,
        format: format,
      );
    }

    if (waveformData.isEmpty) {
      return '';
    }

    final sampled = sampleWaveform(waveformData, maxSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(decimals)))
        .toList(growable: false);

    return switch (format) {
      WaveformTransportFormat.json => jsonEncode(rounded),
      WaveformTransportFormat.csv => rounded.join(','),
    };
  }

  @override
  List<double> decodeWaveform(String? waveformString) {
    if (onDecodeWaveform != null) {
      return onDecodeWaveform!(waveformString);
    }
    if (waveformString == null || waveformString.trim().isEmpty) {
      return const <double>[];
    }

    final normalized = waveformString
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
