import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/comment_audio_controller.dart';
import '../../../models/comment_record_model.dart';
import '../../../utils/format_utils.dart';
import '../abput_photo/user_display_widget.dart';

class VoiceCommentRow extends StatelessWidget {
  final CommentRecordModel comment;
  final bool isHighlighted; // 하이라이트 여부

  const VoiceCommentRow({
    super.key,
    required this.comment,
    this.isHighlighted = false, // 기본값 false
  });

  @override
  Widget build(BuildContext context) {
    // 텍스트 댓글인 경우
    if (comment.type == CommentType.text) {
      return _buildTextCommentRow(context);
    }

    // 음성 댓글인 경우 (기존 로직)
    return _buildAudioCommentRow(context);
  }

  /// 텍스트 댓글 UI
  Widget _buildTextCommentRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.white : null, // 하이라이트 배경색
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isHighlighted ? 12 : 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 이미지
              ClipOval(
                child:
                    comment.profileImageUrl.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: comment.profileImageUrl,
                          width: 44.w,
                          height: 44.w,
                          memCacheHeight: (44 * 2).toInt(),
                          memCacheWidth: (44 * 2).toInt(),
                          fit: BoxFit.cover,
                        )
                        : Container(
                          width: 44.w,
                          height: 44.w,
                          color: const Color(0xFF4E4E4E),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserDisplayName(userId: comment.recorderUser),
                    SizedBox(height: 8.h),
                    // 텍스트 댓글 내용
                    Text(
                      comment.text ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
            ],
          ),
          SizedBox(height: 7.h),
          Row(
            children: [
              Spacer(),
              Text(
                FormatUtils.formatRelativeTime(comment.createdAt),
                style: TextStyle(
                  color: const Color(0xFFC4C4C4),
                  fontSize: 10.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.40,
                ),
              ),
              SizedBox(width: 12.w),
            ],
          ),
        ],
      ),
    );
  }

  /// 음성 댓글 UI (기존 로직)
  Widget _buildAudioCommentRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.black : null, // 하이라이트 배경색
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isHighlighted ? 12 : 0),
      child: Consumer<CommentAudioController>(
        builder: (context, commentAudioController, child) {
          final isPlaying = commentAudioController.isCommentPlaying(comment.id);
          final progress = commentAudioController.getCommentProgress(
            comment.id,
          );
          final position = commentAudioController.getCommentPosition(
            comment.id,
          );
          final duration = commentAudioController.getCommentDuration(
            comment.id,
          );
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 프로필 이미지
                  ClipOval(
                    child:
                        comment.profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: comment.profileImageUrl,
                              width: 44.w,
                              height: 44.w,
                              memCacheHeight: (44 * 2).toInt(),
                              memCacheWidth: (44 * 2).toInt(),
                              fit: BoxFit.cover,
                            )
                            : Container(
                              width: 44.w,
                              height: 44.w,
                              color: const Color(0xFF4E4E4E),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserDisplayName(userId: comment.recorderUser),
                        SizedBox(height: 4.h),
                        _WaveformPlaybackBar(
                          isPlaying: isPlaying,
                          progress: progress,
                          onPlayPause: () async {
                            if (isPlaying) {
                              await commentAudioController.pauseComment(
                                comment.id,
                              );
                            } else {
                              await commentAudioController.playComment(
                                comment.id,
                                comment.audioUrl,
                              );
                            }
                          },
                          position: position,
                          duration: duration,
                          waveformData: comment.waveformData,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                ],
              ),
              SizedBox(height: 7.h),
              Row(
                children: [
                  Spacer(),
                  Text(
                    FormatUtils.formatRelativeTime(comment.createdAt),
                    style: TextStyle(
                      color: const Color(0xFFC4C4C4),
                      fontSize: 10.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.40,
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaveformPlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final double progress; // 0~1
  final Future<void> Function() onPlayPause;
  final Duration position;
  final Duration duration;
  final List<double> waveformData; // 실제 파형 데이터 추가
  const _WaveformPlaybackBar({
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.position,
    required this.duration,
    required this.waveformData, // 필수 파라미터로 추가
  });

  @override
  Widget build(BuildContext context) {
    final totalMs =
        duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds; // div 0 방지
    final playedMs = position.inMilliseconds;
    final barProgress = (playedMs / totalMs).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 25.sp,
            ),
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 회색 배경 파형 (기본 흰색이지만 재생 시 회색으로)
                    GestureDetector(
                      onTap: onPlayPause,
                      child: _buildWaveformBase(
                        color:
                            isPlaying ? const Color(0xFF4A4A4A) : Colors.white,
                        availableWidth: availableWidth,
                      ),
                    ),
                    // 흰색 진행 파형 (재생 중에만 표시)
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
      ),
    );
  }

  Widget _buildWaveformBase({
    required Color color,
    required double availableWidth,
  }) {
    // 파형 바 개수를 40개로 고정
    const maxBars = 40;

    // 실제 waveformData 기반 파형 표현
    if (waveformData.isEmpty) {
      // 데이터가 없으면 기본 패턴 사용
      return SizedBox(
        width: availableWidth, // 고정 너비 설정
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 균등하게 분배
          children: List.generate(maxBars, (i) {
            final h = (i % 5 + 4) * 3.0;
            return Container(
              width: (2.54).w,
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

    // 실제 waveformData 사용
    const minHeight = 4.0;
    const maxHeight = 20.0;

    // 데이터 샘플링 (항상 50개로 샘플링)
    final sampledData = _sampleWaveformData(waveformData, maxBars);

    return Container(
      width: availableWidth, // 고정 너비 설정
      padding: EdgeInsets.only(right: 10.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 균등하게 분배
        children:
            sampledData.asMap().entries.map((entry) {
              final value = entry.value;
              // 0~1 범위의 값을 minHeight~maxHeight로 매핑
              final barHeight = minHeight + (value * (maxHeight - minHeight));

              return Container(
                width: (2.54).w,
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

  /// waveformData를 지정된 수만큼 샘플링
  List<double> _sampleWaveformData(List<double> data, int targetCount) {
    if (data.isEmpty) {
      // 데이터가 없으면 기본 패턴 생성
      return List.generate(targetCount, (i) => (i % 5 + 4) / 10.0);
    }

    if (data.length <= targetCount) {
      // 데이터가 적으면 보간을 통해 확장
      final sampled = <double>[];
      for (int i = 0; i < targetCount; i++) {
        final position = (i * (data.length - 1)) / (targetCount - 1);
        final index = position.floor();
        final fraction = position - index;

        if (index >= data.length - 1) {
          sampled.add(data.last.abs().clamp(0.0, 1.0));
        } else {
          // 선형 보간
          final value1 = data[index].abs();
          final value2 = data[index + 1].abs();
          final interpolated = value1 + (value2 - value1) * fraction;
          sampled.add(interpolated.clamp(0.0, 1.0));
        }
      }
      return sampled;
    }

    // 데이터가 많으면 다운샘플링
    final step = data.length / targetCount;
    final sampled = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        // 절댓값 사용하여 양수로 변환 (음성 데이터는 음수도 포함)
        sampled.add(data[index].abs().clamp(0.0, 1.0));
      }
    }

    return sampled;
  }
}
