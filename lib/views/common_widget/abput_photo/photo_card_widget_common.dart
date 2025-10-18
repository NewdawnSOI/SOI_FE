import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/photo_data_model.dart';
import '../../../models/comment_record_model.dart';
import 'user_info_row_widget.dart';
import '../about_voice_comment/voice_recording_widget.dart';
import 'photo_display_widget.dart';

class PhotoCardWidgetCommon extends StatefulWidget {
  final PhotoDataModel photo;
  final String categoryName;
  final String categoryId;
  final int index;
  final bool isOwner;
  // Archive 화면 여부 (Archive에서는 상단 여백 제거)
  final bool isArchive;
  // 카테고리 화면 여부 (카테고리에서는 하단 여백 추가)
  final bool isCategory;

  // 상태 관리 관련
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Map<String, String> userNames;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, bool> voiceCommentSavedStates;
  final Map<String, bool>? pendingTextComments; // Pending 텍스트 댓글 상태

  // 콜백 함수들
  final Function(PhotoDataModel) onToggleAudio;
  final Function(String) onToggleVoiceComment;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String, String) onTextCommentCompleted; // 텍스트 댓글 완료 콜백
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Future<void> Function(String) onSaveRequested; // 프로필 배치 저장 콜백
  final Function(String) onSaveCompleted;
  final VoidCallback onDeletePressed;
  final VoidCallback onLikePressed;

  const PhotoCardWidgetCommon({
    super.key,
    required this.photo,
    required this.categoryName,
    required this.categoryId,
    required this.index,
    required this.isOwner,
    this.isArchive = false,
    this.isCategory = false,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.userNames,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    this.pendingTextComments, // Pending 텍스트 댓글 상태 추가
    required this.onToggleAudio,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onTextCommentCompleted, // 텍스트 댓글 완료 콜백 추가
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    required this.onSaveRequested,
    required this.onSaveCompleted,
    required this.onDeletePressed,
    required this.onLikePressed,
  });

  @override
  State<PhotoCardWidgetCommon> createState() => _PhotoCardWidgetCommonState();
}

class _PhotoCardWidgetCommonState extends State<PhotoCardWidgetCommon> {
  bool _isTextFieldFocused = false;

  /// 텍스트 댓글 생성 후 프로필 배치를 위한 핸들러
  void _handleTextCommentCreated(String text) async {
    debugPrint(
      '🔵 [PhotoCard] 텍스트 댓글 생성: photoId=${widget.photo.id}, text=$text',
    );
    // 텍스트 댓글을 임시 저장하고 음성 댓글 active 상태로 전환
    await widget.onTextCommentCompleted(widget.photo.id, text);
    debugPrint('🔵 [PhotoCard] onTextCommentCompleted 호출 완료 (await)');
    // 음성 댓글 active 상태로 전환하여 프로필 드래그 가능하게 함
    widget.onToggleVoiceComment(widget.photo.id);
    debugPrint('🔵 [PhotoCard] onToggleVoiceComment 호출 완료');
  }

  @override
  Widget build(BuildContext context) {
    // 텍스트 필드 포커스 상태로 키보드 여부 판단
    final isKeyboardVisible = _isTextFieldFocused;

    // 키보드가 올라오면 10, 아니면 isCategory에 따라 50 또는 10
    final bottomPadding =
        isKeyboardVisible ? 10.0 : (widget.isCategory ? 55.0 : 10.0);

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!widget.isArchive) SizedBox(height: 90.h),

              // 사진 표시 위젯
              PhotoDisplayWidget(
                key: ValueKey(widget.photo.id),
                photo: widget.photo,
                categoryName: widget.categoryName,
                isArchive: widget.isArchive,
                photoComments: widget.photoComments,
                userProfileImages: widget.userProfileImages,
                profileLoadingStates: widget.profileLoadingStates,
                onProfileImageDragged: widget.onProfileImageDragged,
                onToggleAudio: widget.onToggleAudio,
              ),
              SizedBox(height: 12.h),

              // 사용자 정보 위젯 (아이디와 날짜)
              UserInfoWidget(
                photo: widget.photo,
                userNames: widget.userNames,
                isCurrentUserPhoto: widget.isOwner,
                onDeletePressed: widget.onDeletePressed,
                onLikePressed: widget.onLikePressed,
              ),
              SizedBox(height: 10.h),

              // 음성 녹음 위젯을 위한 공간 확보
              SizedBox(height: 90.h),
            ],
          ),
        ),

        // 음성 녹음 위젯을 Stack 위에 배치
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: VoiceRecordingWidget(
            photo: widget.photo,
            voiceCommentActiveStates: widget.voiceCommentActiveStates,
            voiceCommentSavedStates: widget.voiceCommentSavedStates,
            userProfileImages: widget.userProfileImages,
            photoComments: widget.photoComments,
            onToggleVoiceComment: widget.onToggleVoiceComment,
            onVoiceCommentCompleted: widget.onVoiceCommentCompleted,
            onVoiceCommentDeleted: widget.onVoiceCommentDeleted,
            onProfileImageDragged: widget.onProfileImageDragged,
            onSaveRequested: widget.onSaveRequested,
            onSaveCompleted: widget.onSaveCompleted,
            pendingTextComments:
                widget.pendingTextComments, // Pending 텍스트 댓글 상태 전달
            onTextFieldFocusChanged: (isFocused) {
              setState(() {
                _isTextFieldFocused = isFocused;
              });
            },
            onTextCommentCreated: _handleTextCommentCreated, // 텍스트 댓글 생성 콜백 연결
          ),
        ),
      ],
    );
  }
}
