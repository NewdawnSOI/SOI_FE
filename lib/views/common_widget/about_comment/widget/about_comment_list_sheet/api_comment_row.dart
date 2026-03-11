import 'dart:convert';

// 외부 패키지
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// 내부 모듈
import '../../../../../api/controller/audio_controller.dart';
import '../../../../../api/controller/friend_controller.dart';
import '../../../../../api/controller/post_controller.dart';
import '../../../../../api/controller/user_controller.dart';
import '../../../../../api/models/comment.dart';
import '../../../../../utils/format_utils.dart';
import '../../../../about_feed/manager/feed_data_manager.dart';
import '../../../report/report_bottom_sheet.dart';
import 'api_comment_media_preview.dart';
import 'api_waveform_playback_bar.dart';

/// 댓글 하나를 보여주는 위젯
/// 댓글의 타입에 따라 텍스트, 오디오, 이미지/동영상 미리보기 등을 표시합니다.
/// 댓글 작성자의 프로필 이미지와 닉네임도 함께 보여줍니다.
/// 댓글이 작성자 본인의 것이 아닌 경우, 신고 및 차단 메뉴도 표시됩니다.
class ApiCommentRow extends StatelessWidget {
  static const double _baseHorizontalPadding = 27.0;
  static const double _profileImageSize = 38.0;
  static const double _profileToContentGap = 12.0;

  final Comment comment;
  final bool isHighlighted;
  final ValueChanged<Comment>? onReplyTap;
  final bool showViewMoreRepliesButton;
  final bool showHideRepliesButton;
  final ValueChanged<Comment>? onViewMoreRepliesTap;
  final ValueChanged<Comment>? onHideRepliesTap;

  const ApiCommentRow({
    super.key,
    required this.comment,
    this.isHighlighted = false,
    this.onReplyTap,
    this.showViewMoreRepliesButton = false,
    this.showHideRepliesButton = false,
    this.onViewMoreRepliesTap,
    this.onHideRepliesTap,
  });

  bool _canShowActions(String? currentUserId) {
    if (currentUserId == null || currentUserId.isEmpty) return false;
    if (comment.nickname == null || comment.nickname!.isEmpty) return false;
    return comment.nickname != currentUserId;
  }

  Future<void> _reportUser(BuildContext context) async {
    final result = await ReportBottomSheet.show(context);
    if (result == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('신고가 접수되었습니다. 신고 내용을 관리자가 확인 후, 판단 후에 처리하도록 하겠습니다.'),
        backgroundColor: Color(0xFF5A5A5A),
      ),
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();
    final feedDataManager = context.read<FeedDataManager>();
    final postController = context.read<PostController>();
    final messenger = ScaffoldMessenger.of(context);
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.login_required')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final shouldBlock = await _showBlockConfirmation(context);
    if (shouldBlock != true) return;
    if (!context.mounted) return;

    final nickname = comment.nickname ?? '';
    if (nickname.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.user_info_unavailable')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final targetUser = await userController.getUserByNickname(nickname);
    if (targetUser == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.user_info_unavailable')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
      return;
    }

    final ok = await friendController.blockFriend(
      requesterId: currentUser.id,
      receiverId: targetUser.id,
    );
    if (!context.mounted) return;

    if (ok) {
      feedDataManager.removePostsByNickname(nickname);
      postController.notifyPostsChanged();
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.block_success')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('common.block_failed')),
          backgroundColor: const Color(0xFF5A5A5A),
        ),
      );
    }
  }

  Future<bool?> _showBlockConfirmation(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xff323232),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 17.sp),
              Text(
                '차단 하시겠습니까?',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 19.78.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.sp),
              SizedBox(
                height: 38.sp,
                width: 344.sp,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xfff5f5f5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '예',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.sp),
              SizedBox(
                height: 38.sp,
                width: 344.sp,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF323232),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2.r),
                    ),
                  ),
                  child: Text(
                    '아니오',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30.sp),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.white, size: 20.sp),
      color: const Color(0xFF323232),
      onSelected: (value) {
        if (value == 'report') {
          _reportUser(context);
        } else if (value == 'block') {
          _blockUser(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Text(
            tr('common.report', context: context),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Text(
            tr('common.block', context: context),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (comment.type) {
      case CommentType.text:
        return _buildTextRow(context);
      case CommentType.audio:
        return _buildAudioRow(context);
      case CommentType.photo:
        return _buildMediaRow(context);
      case CommentType.video:
        return _buildMediaRow(context);
      case CommentType.reply:
        return _buildTextRow(context);
    }
  }

  String get _profileUrl {
    final profileUrl = (comment.userProfileUrl ?? '').trim();
    if (profileUrl.isNotEmpty) {
      return profileUrl;
    }
    return (comment.userProfileKey ?? '').trim();
  }

  String get _userName {
    final nickname = comment.nickname ?? '알 수 없는 사용자';
    final replyUserName = comment.replyUserName?.trim() ?? '';
    if (!comment.isReply || replyUserName.isEmpty) {
      return nickname;
    }
    return '$nickname --- $replyUserName';
  }

  bool _shouldShowActions(BuildContext context) {
    final currentUserId = context.read<UserController>().currentUser?.userId;
    return _canShowActions(currentUserId);
  }

  TextStyle _userNameStyle() => TextStyle(
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

  /// "답장 달기"와 댓글 작성 시각이 있는 행을 빌드하는 메서드
  Widget _buildReplyAndTimeRow() {
    return Row(
      children: [
        SizedBox(width: (_profileImageSize + _profileToContentGap).sp),

        // "답장 달기" 버튼
        TextButton(
          onPressed: () => onReplyTap?.call(comment),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(tr('comments.reply_action'), style: _replyActionStyle()),
        ),
        const Spacer(),

        // 댓글 작성 시각
        Text(
          comment.createdAt != null
              ? FormatUtils.formatRelativeTime(comment.createdAt!)
              : '',
          style: _relativeTimeStyle(),
        ),
        SizedBox(width: 12.sp),
      ],
    );
  }

  /// "답글 보기"/"답글 숨기기" 버튼을 빌드하는 메서드
  Widget _buildReplyVisibilityButton() {
    final replyCount = comment.replyUserCount ?? 0;

    if (comment.isReply || replyCount <= 0) {
      return const SizedBox.shrink();
    }

    if (!showViewMoreRepliesButton && !showHideRepliesButton) {
      return const SizedBox.shrink();
    }

    final buttonText = showHideRepliesButton
        ?
          // 답글 숨기기
          tr('comments.hide_replies')
        :
          // 답글 보기 (답글 개수 표시)
          tr(
            'comments.view_more_replies',
            namedArgs: {'count': replyCount.toString()},
          );

    return Padding(
      padding: EdgeInsets.only(top: 30.sp),
      child: Row(
        children: [
          SizedBox(width: (_profileImageSize + _profileToContentGap).sp),

          // 답글 보기 / 답글 숨기기 버튼
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

  Widget _wrapRowContent(Widget content) {
    final horizontalPadding = EdgeInsets.only(
      left: comment.isReply
          ? (_baseHorizontalPadding + _profileImageSize + _profileToContentGap)
                .sp
          : _baseHorizontalPadding.sp,
      right: _baseHorizontalPadding.sp,
    );

    if (isHighlighted) {
      return Container(
        color: const Color(0xff000000).withValues(alpha: 0.23),
        padding: horizontalPadding.add(EdgeInsets.symmetric(vertical: 10.sp)),
        child: content,
      );
    }

    return Padding(padding: horizontalPadding, child: content);
  }

  Widget _buildCommentRowLayout({
    required BuildContext context,
    required Widget body,
    required bool showActions,
    double bodySpacing = 8,
  }) {
    return _wrapRowContent(
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
                    Text(_userName, style: _userNameStyle()),
                    if (bodySpacing > 0) SizedBox(height: bodySpacing.sp),
                    body,
                  ],
                ),
              ),
              if (showActions) _buildActionMenu(context),
              SizedBox(width: 10.sp),
            ],
          ),
          SizedBox(height: 7.sp),
          _buildReplyAndTimeRow(),
          _buildReplyVisibilityButton(),
        ],
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

  Widget _buildTextRow(BuildContext context) {
    return _buildCommentRowLayout(
      context: context,
      showActions: _shouldShowActions(context),
      body: _buildTextCommentText(comment.text ?? ''),
    );
  }

  Widget _buildAudioRow(BuildContext context) {
    final waveformData = _parseWaveformData(comment.waveformData);
    final showActions = _shouldShowActions(context);

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying = audioController.isUrlPlaying(comment.audioUrl ?? '');
        return _buildCommentRowLayout(
          context: context,
          showActions: showActions,
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

  Widget _buildMediaRow(BuildContext context) {
    final mediaSource = _resolveMediaSource();
    if (mediaSource == null) {
      return _buildTextRow(context);
    }

    final isVideo = _isVideoMediaSource(mediaSource);
    final cacheKey = (comment.fileKey ?? '').trim().isEmpty
        ? mediaSource
        : comment.fileKey!;
    final trimmedText = (comment.text ?? '').trim();

    return _buildCommentRowLayout(
      context: context,
      showActions: _shouldShowActions(context),
      bodySpacing: 6,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: ApiCommentMediaPreview(
              source: mediaSource,
              isVideo: isVideo,
              cacheKey: cacheKey,
            ),
          ),
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
    return ClipOval(
      child: profileUrl != null && profileUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: profileUrl,
              width: _profileImageSize.sp, // 38.sp
              height: _profileImageSize.sp, // 38.sp
              memCacheHeight: (_profileImageSize * 2).toInt(),
              memCacheWidth: (_profileImageSize * 2).toInt(),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: _profileImageSize.sp, // 38.sp
                height: _profileImageSize.sp, // 38.sp
                color: const Color(0xFF4E4E4E),
              ),
              errorWidget: (context, url, error) => Container(
                width: _profileImageSize.sp, // 38.sp
                height: _profileImageSize.sp, // 38.sp
                color: const Color(0xFF4E4E4E),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            )
          : Container(
              width: _profileImageSize.sp,
              height: _profileImageSize.sp,
              color: const Color(0xFF4E4E4E),
              child: const Icon(Icons.person, color: Colors.white),
            ),
    );
  }

  List<double> _parseWaveformData(String? waveformString) {
    if (waveformString == null || waveformString.isEmpty) {
      return [];
    }

    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return [];

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();
      if (sanitized.isEmpty) return [];

      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);

      try {
        final values = parts.map((part) => double.parse(part)).toList();
        return values;
      } catch (_) {
        debugPrint('waveformData 파싱 실패: $e');
      }
    }

    return [];
  }
}
