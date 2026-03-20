import 'package:flutter/material.dart';
import 'dart:math';

// 파형을 그리는 커스텀 페인터
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final Color activeColor;
  final double progress;
  final double barThickness;
  final double barSpacing;
  final double maxBarHeightFactor;
  final double amplitudeScale;
  final double amplitudeExponent;
  final double minBarHeight;
  final bool fitToWidth;
  final bool alignRight;
  final StrokeCap strokeCap;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.activeColor,
    required this.progress,
    this.barThickness = 3.0,
    this.barSpacing = 7.0,
    this.maxBarHeightFactor = 0.5,
    this.amplitudeScale = 1.0,
    this.amplitudeExponent = 1.0,
    this.minBarHeight = 0.0,
    this.fitToWidth = true,
    this.alignRight = false,
    this.strokeCap = StrokeCap.round,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final effectiveSpacing = barSpacing <= 0 ? 1.0 : barSpacing;
    final barCount = max(1, (size.width / effectiveSpacing).floor());
    final effectiveHeightFactor = maxBarHeightFactor.clamp(0.0, 1.0);
    final effectiveAmplitudeScale = amplitudeScale <= 0 ? 1.0 : amplitudeScale;
    final effectiveMinBarHeight = minBarHeight < 0 ? 0.0 : minBarHeight;

    final paint = Paint()
      ..strokeWidth = barThickness
      ..strokeCap = strokeCap;

    // 재생 파형은 전체 폭에 맞게 샘플링하고, 실시간 파형은 최근 샘플만 유지합니다.
    final sampledData = _prepareData(waveformData, barCount);
    final barsToDraw = sampledData.length;
    final effectiveExponent = amplitudeExponent <= 0 ? 1.0 : amplitudeExponent;

    final centerY = size.height / 2;

    // 파형의 최대 바의 높이는 전체적으로 조절하는 부분
    final maxBarHeight = size.height * effectiveHeightFactor;
    final waveformWidth = barsToDraw <= 1
        ? 0.0
        : (barsToDraw - 1) * effectiveSpacing;
    final startX = alignRight
        ? max(0.0, size.width - waveformWidth - barThickness)
        : 0.0;

    for (int i = 0; i < barsToDraw; i++) {
      final x = startX + (i * effectiveSpacing);
      if (x >= size.width) break;

      // 파형 높이 계산 (0.0 ~ 1.0 범위의 데이터를 바 높이로 변환)
      final shapedValue = pow(
        sampledData[i].clamp(0.0, 1.0),
        effectiveExponent,
      ).toDouble();
      final normalizedHeight = (shapedValue * effectiveAmplitudeScale).clamp(
        0.0,
        1.0,
      );
      var barHeight = max(
        effectiveMinBarHeight,
        normalizedHeight * maxBarHeight,
      );
      barHeight = barHeight.clamp(0.0, maxBarHeight);

      // 진행 상태에 따라 색상 결정
      final isActive = progress > 0 && (i / max(1, barsToDraw)) <= progress;
      paint.color = isActive ? activeColor : color;

      // 파형 바 그리기 (중앙에서 위아래로)
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  List<double> _prepareData(List<double> data, int targetCount) {
    if (data.isEmpty) return const [];
    if (fitToWidth) {
      return _stretchData(data, targetCount);
    }
    if (data.length <= targetCount) {
      return List<double>.from(data);
    }
    if (alignRight) {
      return data.sublist(data.length - targetCount);
    }
    return data.sublist(0, targetCount);
  }

  // 파형 데이터를 지정된 개수로 늘려서 전체 너비를 채움
  List<double> _stretchData(List<double> data, int targetCount) {
    if (data.isEmpty) return List.filled(targetCount, 0.0);
    if (data.length >= targetCount) {
      // 데이터가 충분히 많으면 샘플링
      return _sampleData(data, targetCount);
    }

    // 데이터가 부족하면 보간(interpolation)으로 늘림
    final stretchedData = <double>[];
    final ratio = (data.length - 1) / (targetCount - 1);

    for (int i = 0; i < targetCount; i++) {
      final index = i * ratio;
      final lowerIndex = index.floor();
      final upperIndex = (lowerIndex + 1).clamp(0, data.length - 1);
      final fraction = index - lowerIndex;

      // 선형 보간
      final interpolatedValue =
          data[lowerIndex] * (1 - fraction) + data[upperIndex] * fraction;
      stretchedData.add(interpolatedValue);
    }

    return stretchedData;
  }

  // 파형 데이터를 지정된 개수로 샘플링
  List<double> _sampleData(List<double> data, int targetCount) {
    if (data.length <= targetCount) return data;

    final step = data.length / targetCount;
    final sampledData = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * step).floor();
      final endIndex = ((i + 1) * step).floor().clamp(0, data.length);

      // 구간 내 RMS(Root Mean Square) 사용 (더 실제적인 음성 레벨)
      double sum = 0.0;
      int count = 0;

      // 제곱값의 합
      for (int j = startIndex; j < endIndex; j++) {
        sum += data[j] * data[j];
        count++;
      }
      double rmsValue = count > 0 ? sqrt(sum / count) : 0.0;
      sampledData.add(rmsValue);
    }

    return sampledData;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! WaveformPainter ||
        oldDelegate.waveformData != waveformData ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.barThickness != barThickness ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.maxBarHeightFactor != maxBarHeightFactor ||
        oldDelegate.amplitudeScale != amplitudeScale ||
        oldDelegate.amplitudeExponent != amplitudeExponent ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.fitToWidth != fitToWidth ||
        oldDelegate.alignRight != alignRight ||
        oldDelegate.strokeCap != strokeCap;
  }
}
