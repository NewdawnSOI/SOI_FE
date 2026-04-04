import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 오디오 댓글의 재생 상태를 보여주는 위젯
/// [isPlaying]이 true이면 재생 중인 상태로, false이면 일시정지된 상태로 표시됩니다.
/// [position]과 [duration]을 기반으로 재생 진행 상황을 시각적으로 나타냅니다.
/// [waveformData]는 오디오의 파형 데이터를 나타내며, 재생 진행 상황에 따라 색상이 변경됩니다.
///
/// Parameters:
/// - [isPlaying]: 오디오가 현재 재생 중인지 여부
/// - [onPlayPause]: 재생/일시정지 버튼이 눌렸을 때 호출되는 콜백 함수
/// - [position]: 오디오의 현재 재생 위치
/// - [duration]: 오디오의 전체 길이
/// - [waveformData]: 오디오의 파형 데이터를 나타내는 리스트. 각 값은 0.0에서 1.0 사이의 범위를 가지며, 오디오의 볼륨 레벨을 나타냅니다.
///
/// Returns:
/// - 재생/일시정지 버튼과 함께, 오디오의 재생 진행 상황을 시각적으로 나타내는 파형 바가 표시됩니다.
///   재생 중인 경우, 파형 바는 흰색으로 표시되고, 일시정지된 경우에는 회색으로 표시됩니다.
class ApiWaveformPlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final Future<void> Function() onPlayPause;
  final Duration position;
  final Duration duration;
  final List<double> waveformData;

  const ApiWaveformPlaybackBar({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.position,
    required this.duration,
    required this.waveformData,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds;
    final playedMs = position.inMilliseconds;
    final barProgress = (playedMs / totalMs).clamp(0.0, 1.0);

    return Row(
      children: [
        // 재생/일시정지 버튼
        IconButton(
          onPressed: onPlayPause,
          icon: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 25.sp,
          ),
        ),
        // 파형 바
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  GestureDetector(
                    onTap: onPlayPause,
                    child: _buildWaveformBase(
                      color: isPlaying ? const Color(0xFF4A4A4A) : Colors.white,
                      availableWidth: availableWidth,
                    ),
                  ),
                  if (isPlaying)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: barProgress,
                        child: _buildWaveformBase(
                          color: Colors.white,
                          availableWidth: availableWidth,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 파형 바의 기본 레이아웃을 생성하는 메서드
  Widget _buildWaveformBase({
    required Color color,
    required double availableWidth,
  }) {
    const maxBars = 40;

    if (waveformData.isEmpty) {
      return SizedBox(
        width: availableWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(maxBars, (i) {
            final h = (i % 5 + 4) * 3.0;
            return Container(
              width: (2.54).sp,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      );
    }

    const minHeight = 4.0;
    const maxHeight = 20.0;

    final sampledData = _sampleWaveformData(waveformData, maxBars);

    return Container(
      width: availableWidth,
      padding: EdgeInsets.only(right: 10.sp),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: sampledData.asMap().entries.map((entry) {
          final value = entry.value;
          final barHeight = minHeight + (value * (maxHeight - minHeight));

          return Container(
            width: (2.54).sp,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<double> _sampleWaveformData(List<double> data, int targetCount) {
    if (data.isEmpty) {
      return List.generate(targetCount, (i) => (i % 5 + 4) / 10.0);
    }

    if (data.length <= targetCount) {
      final sampled = <double>[];
      for (int i = 0; i < targetCount; i++) {
        final position = (i * (data.length - 1)) / (targetCount - 1);
        final index = position.floor();
        final fraction = position - index;

        if (index >= data.length - 1) {
          sampled.add(data.last.abs().clamp(0.0, 1.0));
        } else {
          final value1 = data[index].abs();
          final value2 = data[index + 1].abs();
          final interpolated = value1 + (value2 - value1) * fraction;
          sampled.add(interpolated.clamp(0.0, 1.0));
        }
      }
      return sampled;
    }

    final step = data.length / targetCount;
    final sampled = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        sampled.add(data[index].abs().clamp(0.0, 1.0));
      }
    }

    return sampled;
  }
}
