// 외부 패키지
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// 내부 모듈
import '../../../../../api/controller/audio_controller.dart';
import '../../../../../api/models/comment.dart';
import '../../../../../utils/format_utils.dart';
import '../../comment_circle_avatar.dart';
import '../../../photo/services/photo_waveform_parser_service.dart';
import '../../../user/current_user_image_builder.dart';
import 'comment_media_preview.dart';
import 'waveform_playback_bar.dart';

/// 댓글 하나를 보여주는 위젯
/// 댓글의 타입별 본문을 렌더링하고 롱프레스 시 행 확대 상태만 반영합니다.
class ApiCommentRow extends StatelessWidget {
  static const double _baseHorizontalPadding =
      27.0; // 댓글 행의 기본 좌우 패딩 (프로필 이미지와 댓글 내용 사이의 간격 포함)
  static const double _profileImageSize = 38.0; // 프로필 이미지 크기 (답글이 아닌 경우)
  static const double _replyProfileImageSize = 32.13; // 답글인 경우 프로필 이미지 크기를 줄임
  static const double _profileToContentGap = 12.0; // 프로필 이미지와 댓글 내용 사이의 간격
  static const double _mediaPreviewFrameSize = 137.0; // 미디어 미리보기 프레임 크기
  static const double _replyMediaPreviewSize = 85.0; // 답글 미디어 미리보기 최대 크기
  static const Color _highlightColor = Color(0x3B000000);
  static const Duration _rowAnimationDuration = Duration(milliseconds: 220);
  static const double _changeCommentRowScale = 0.9; // 롱프레스 시 행 확대 비율

  final Comment comment;
  final bool isHighlighted;
  final ValueChanged<Comment>? onReplyTap;
  final VoidCallback? onLongPress;
  final bool showReplyAction;
  final bool showViewMoreRepliesButton;
  final bool showHideRepliesButton;
  final ValueChanged<Comment>? onViewMoreRepliesTap;
  final ValueChanged<Comment>? onHideRepliesTap;
  final String? relativeTimeText;
  final bool isActionExpanded;

  const ApiCommentRow({
    super.key,
    required this.comment,
    this.isHighlighted = false,
    this.onReplyTap,
    this.onLongPress,
    this.showReplyAction = true,
    this.showViewMoreRepliesButton = false,
    this.showHideRepliesButton = false,
    this.onViewMoreRepliesTap,
    this.onHideRepliesTap,
    this.relativeTimeText,
    this.isActionExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (comment.isReply) {
      if (_resolveMediaSource() != null) {
        return _buildMediaRow(context);
      }
      final audioUrl = (comment.audioUrl ?? '').trim();
      final waveformData = (comment.waveformData ?? '').trim();
      if (audioUrl.isNotEmpty || waveformData.isNotEmpty) {
        return _buildAudioRow(context);
      }
      return _buildTextRow();
    }

    switch (comment.type) {
      case CommentType.text:
        return _buildTextRow();
      case CommentType.audio:
        return _buildAudioRow(context);
      case CommentType.photo:
        return _buildMediaRow(context);
      case CommentType.video:
        return _buildMediaRow(context);
      case CommentType.reply:
        return _buildTextRow();
    }
  }

  String get _profileUrl {
    final profileUrl = (comment.userProfileUrl ?? '').trim();
    if (profileUrl.isNotEmpty) {
      return profileUrl;
    }
    return (comment.userProfileKey ?? '').trim();
  }

  double get _effectiveProfileImageSize =>
      comment.isReply ? _replyProfileImageSize : _profileImageSize;

  /// 대댓글 닉네임 행은 작성자와 수신자를 한 줄에서 구분해 보여줍니다.
  Widget _buildUserNameWidget() {
    final nickname = comment.nickname ?? '알 수 없는 사용자';
    final replyUserName = comment.replyUserName?.trim() ?? '';
    final style = _userNameStyle();

    if (!comment.isReply || replyUserName.isEmpty) {
      return Text(
        nickname,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            nickname,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.sp),
          child: Container(width: 18.sp, height: 1.0, color: Colors.white),
        ),
        Flexible(
          child: Text(
            replyUserName,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  TextStyle _userNameStyle() => comment.isReply
      ? TextStyle(
          color: Colors.white,
          fontSize: 10.99.sp,
          fontFamily: 'Pretendard Variable',
          fontWeight: FontWeight.w500,
          letterSpacing: -0.34,
        )
      : TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
        );

  /// 댓글 작성 시각 텍스트의 스타일
  TextStyle _relativeTimeStyle() => TextStyle(
    color: const Color(0xFFC4C4C4),
    fontSize: 10.sp,
    fontFamily: 'Pretendard',
    fontWeight: FontWeight.w500,
    letterSpacing: -0.40,
  );

  /// "답장 달기" 버튼 텍스트의 스타일
  TextStyle _replyActionStyle() => TextStyle(
    color: Colors.white,
    fontSize: 10.sp,
    fontFamily: 'Pretendard Variable',
    fontWeight: FontWeight.w500,
    letterSpacing: -0.50,
  );

  /// "답글 보기"/"답글 숨기기" 버튼 텍스트의 스타일
  TextStyle _replyVisibilityButtonStyle() => TextStyle(
    color: Colors.white,
    fontSize: 12.sp,
    fontFamily: 'Pretendard Variable',
    fontWeight: FontWeight.w700,
    letterSpacing: -0.50,
  );

  /// 댓글 메타 영역이 모델에서 정규화한 createdAt을 일관된 상대 시간 문자열로 변환합니다.
  String _resolvedRelativeTimeText() {
    final overrideText = relativeTimeText?.trim();
    if (overrideText != null && overrideText.isNotEmpty) {
      return overrideText;
    }
    if (comment.createdAt == null) {
      return '';
    }
    return FormatUtils.formatRelativeTime(comment.createdAt!);
  }

  /// "답장 달기"와 댓글 작성 시각이 있는 하단 메타 행을 빌드합니다.
  Widget _buildReplyAndTimeRow() {
    return Row(
      children: [
        SizedBox(width: (_effectiveProfileImageSize + _profileToContentGap).sp),
        if (showReplyAction)
          TextButton(
            onPressed: () => onReplyTap?.call(comment),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              tr('comments.reply_action'),
              style: _replyActionStyle(),
            ),
          ),
        const Spacer(),
        Text(_resolvedRelativeTimeText(), style: _relativeTimeStyle()),
        SizedBox(width: 12.sp),
      ],
    );
  }

  /// "답글 보기"/"답글 숨기기" 버튼은 원댓글 스레드 펼침 상태를 토글합니다.
  Widget _buildReplyVisibilityButton() {
    final replyCount = comment.replyCommentCount ?? 0;

    if (comment.isReply || replyCount <= 0) {
      return const SizedBox.shrink();
    }

    if (!showViewMoreRepliesButton && !showHideRepliesButton) {
      return const SizedBox.shrink();
    }

    final buttonText = showHideRepliesButton
        ? tr('comments.hide_replies')
        : tr(
            'comments.view_more_replies',
            namedArgs: {'count': replyCount.toString()},
          );

    return Padding(
      padding: EdgeInsets.only(top: 30.sp),
      child: Row(
        children: [
          SizedBox(width: (_profileImageSize + _profileToContentGap).sp),
          TextButton(
            onPressed: () {
              if (showHideRepliesButton) {
                onHideRepliesTap?.call(comment);
                return;
              }
              onViewMoreRepliesTap?.call(comment);
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(buttonText, style: _replyVisibilityButtonStyle()),
          ),
        ],
      ),
    );
  }

  /// 댓글 행의 공통 패딩과 스레드 강조 배경을 감싸는 래퍼입니다.
  Widget _wrapRowContent(Widget content) {
    final horizontalPadding = EdgeInsets.only(
      left: comment.isReply
          ? (_baseHorizontalPadding +
                    _effectiveProfileImageSize +
                    _profileToContentGap)
                .sp
          : _baseHorizontalPadding.sp,
      right: _baseHorizontalPadding.sp,
    );

    if (isHighlighted) {
      return Container(
        width: double.infinity,
        color: _highlightColor,
        child: Padding(
          padding: horizontalPadding.add(
            EdgeInsets.only(top: 10.sp, bottom: 10.sp),
          ),
          child: content,
        ),
      );
    }

    return Padding(
      padding: horizontalPadding.add(
        EdgeInsets.only(top: 10.sp, bottom: 10.sp),
      ),
      child: content,
    );
  }

  /// 댓글 본문을 하나의 롱프레스 가능한 행으로 조립합니다.
  Widget _buildCommentRowLayout({
    required Widget body,
    double bodySpacing = 8,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: AnimatedScale(
        scale: isActionExpanded ? _changeCommentRowScale : 1,
        duration: _rowAnimationDuration,
        curve: Curves.easeOutCubic,
        child: _wrapRowContent(
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileImage(_profileUrl),
                  SizedBox(width: 12.sp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserNameWidget(),
                        if (bodySpacing > 0) SizedBox(height: bodySpacing.sp),
                        body,
                      ],
                    ),
                  ),
                  SizedBox(width: 10.sp),
                ],
              ),
              SizedBox(height: 7.sp),
              _buildReplyAndTimeRow(),
              _buildReplyVisibilityButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextCommentText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
    );
  }

  /// 텍스트 댓글은 공통 행 레이아웃에 본문만 끼워 넣어 렌더링합니다.
  Widget _buildTextRow() {
    return _buildCommentRowLayout(
      body: _buildTextCommentText(comment.text ?? ''),
    );
  }

  /// 오디오 댓글은 재생 상태를 구독하면서 공통 행 레이아웃에 파형 바를 렌더링합니다.
  Widget _buildAudioRow(BuildContext context) {
    final waveformData =
        ApiPhotoWaveformParserService.parse(comment.waveformData) ?? const [];

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.isUrlPlaying(comment.audioUrl ?? '');
        return _buildCommentRowLayout(
          bodySpacing: 4,
          body: ApiWaveformPlaybackBar(
            isPlaying: isPlaying,
            onPlayPause: () async {
              final audioUrl = comment.audioUrl;
              if (audioUrl == null || audioUrl.isEmpty) {
                return;
              }
              if (isPlaying) {
                await audioController.pause();
              } else {
                await audioController.play(audioUrl);
              }
            },
            position: isPlaying
                ? audioController.currentPosition
                : Duration.zero,
            duration: isPlaying
                ? audioController.totalDuration
                : Duration(milliseconds: comment.duration ?? 0),
            waveformData: waveformData,
          ),
        );
      },
    );
  }

  String? _resolveMediaSource() {
    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    if (fileKey.isNotEmpty) {
      return fileKey;
    }
    return null;
  }

  bool _isVideoMediaSource(String source) {
    final normalized = source.split('?').first.split('#').first.toLowerCase();
    const videoExtensions = <String>[
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    return videoExtensions.any(normalized.endsWith);
  }

  /// 미디어 댓글은 미리보기와 텍스트 캡션을 공통 행 레이아웃에 함께 배치합니다.
  Widget _buildMediaRow(BuildContext context) {
    final mediaSource = _resolveMediaSource();
    if (mediaSource == null) {
      return _buildTextRow();
    }

    final isVideo = _isVideoMediaSource(mediaSource);
    final cacheKey = (comment.fileKey ?? '').trim().isEmpty
        ? mediaSource
        : comment.fileKey!;
    final trimmedText = (comment.text ?? '').trim();
    final mediaPreview = comment.isReply
        ? SizedBox(
            width: _replyMediaPreviewSize.sp,
            height: _replyMediaPreviewSize.sp,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _mediaPreviewFrameSize.sp,
                height: _mediaPreviewFrameSize.sp,
                child: ApiCommentMediaPreview(
                  source: mediaSource,
                  isVideo: isVideo,
                  cacheKey: cacheKey,
                ),
              ),
            ),
          )
        : ApiCommentMediaPreview(
            source: mediaSource,
            isVideo: isVideo,
            cacheKey: cacheKey,
          );

    return _buildCommentRowLayout(
      bodySpacing: 6,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(alignment: Alignment.center, child: mediaPreview),
          if (trimmedText.isNotEmpty) ...[
            SizedBox(height: 8.sp),
            Text(
              trimmedText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileImage(String? profileUrl) {
    return _CommentRowAvatar(
      commentUserId: comment.userId,
      commentNickname: comment.nickname,
      fallbackProfileUrl: profileUrl,
      fallbackProfileKey: comment.userProfileKey,
      size: _effectiveProfileImageSize.sp,
    );
  }
}

/// 댓글 아바타만 현재 사용자 이미지 selector를 구독해 행 전체 재빌드를 막습니다.
class _CommentRowAvatar extends StatelessWidget {
  const _CommentRowAvatar({
    required this.commentUserId,
    required this.commentNickname,
    required this.fallbackProfileUrl,
    required this.fallbackProfileKey,
    required this.size,
  });

  final int? commentUserId;
  final String? commentNickname;
  final String? fallbackProfileUrl;
  final String? fallbackProfileKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: commentUserId,
      targetUserHandle: commentNickname,
      fallbackImageUrl: fallbackProfileUrl,
      fallbackImageKey: fallbackProfileKey,
      builder: (context, imageUrl, cacheKey) {
        return CommentCircleAvatar(
          imageUrl: imageUrl,
          size: size,
          cacheKey: cacheKey,
        );
      },
    );
  }
}
