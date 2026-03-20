import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../api/models/comment.dart';
import '../../../api/services/media_service.dart';
import 'comment_audio_recording_bottom_sheet_widget.dart';
import 'comment_camera_bottom_sheet_widget.dart';
import 'comment_text_input_widget.dart';
import 'widget/about_comment_list_sheet/api_comment_row.dart';

/// 댓글 리스트를 보여주는 바텀 시트
/// Comment.dart(Model)을 사용하여 댓글 정보를 표시합니다.
/// API의 CommentRespDto와 달리, Comment 모델은 UI/도메인 레이어에서 사용하기 위한 모델입니다.
class ApiVoiceCommentListSheet extends StatefulWidget {
  final int postId;
  final List<Comment> comments;
  final String? selectedCommentId;
  final ValueChanged<List<Comment>>? onCommentsUpdated;

  const ApiVoiceCommentListSheet({
    super.key,
    required this.postId,
    required this.comments,
    this.selectedCommentId,
    this.onCommentsUpdated,
  });

  @override
  State<ApiVoiceCommentListSheet> createState() =>
      _ApiVoiceCommentListSheetState();
}

class _ApiVoiceCommentListSheetState extends State<ApiVoiceCommentListSheet> {
  // 시트 높이는 화면 높이의 60%로 설정합니다. (디자인 시안 기준)
  static const double _sheetHeightFactor = 0.6;

  // 댓글 리스트에서 각 댓글 사이에 들어가는 구분선 위젯의 수직 패딩입니다. (댓글과 댓글 사이의 간격을 조절하는 용도)
  static const double _commentDividerVerticalPadding = 20.0;
  static const Color _commentHighlightColor = Color(0x3B000000);

  // 댓글 저장을 시도할 때, 저장된 댓글 정보를 찾기 위해 API에서 댓글 리스트를 조회하는 최대 시도 횟수입니다.
  // API 응답이 지연되거나 불완전한 경우에도 저장된 댓글 정보를 최대한 복원하기 위한 전략의 일환으로 사용됩니다.
  static const int _savedCommentLookupAttempts = 4;

  // 저장된 댓글을 찾기 위해 각 시도 사이에 기다리는 지연 시간입니다.
  // API 응답이 지연되거나 불완전한 경우에도 저장된 댓글 정보를 최대한 복원하기 위한 전략의 일환으로 사용됩니다.
  static const Duration _savedCommentLookupDelay = Duration(milliseconds: 180);

  // 음성 댓글의 웨이브폼 데이터는 최대 30개 샘플로 줄여서 서버에 전송합니다.
  static const int _maxWaveformSamples = 30;

  late final ScrollController _scrollController;
  late final TextEditingController _replyDraftController;
  late final FocusNode _replyDraftFocusNode;
  late final List<Comment> _comments;
  final GlobalKey _commentListViewportKey = GlobalKey(
    debugLabel: 'comment_list_viewport',
  );
  final Map<String, GlobalKey> _commentKeys = <String, GlobalKey>{};
  final Set<String> _expandedReplyParentKeys = <String>{};

  // 특정 댓글 스레드를 수동으로 강조 표시하기 위한 키입니다.
  // null이면 선택된 댓글 기준으로 자동 강조 표시합니다.
  String? _manuallyHighlightedThreadKey;

  // 현재 대댓글 입력 모드로 진입한 상태에서, 답글 대상 댓글을 나타내는 변수입니다.
  // null이면 대댓글 입력 모드가 아닌 상태입니다.
  Comment? _replyTargetComment;

  // 카메라/미디어 첨부 시트에서 답글 대상 댓글을 참조하기 위한 변수입니다.
  // 대댓글 입력 모드로 진입했을 때의 답글 대상을 참조합니다.
  Comment? _attachmentReplyTarget;

  // 대댓글 입력 모드로 진입했는지 여부를 나타내는 플래그입니다.
  // 이 플래그가 true인 상태에서 입력 필드에 텍스트가 없는 경우에도 대댓글 입력 모드가 유지됩니다.
  bool _isReplyDraftArmed = false;

  // 텍스트 입력 모드로 진입했는지 여부를 나타내는 플래그입니다.
  bool _isTextInputMode = false;

  // 첨부 기능 시트(카메라, 음성)가 열려있는지 여부를 나타내는 플래그입니다.
  bool _isOpeningAttachmentSheet = false;

  // 텍스트 입력 모드로 진입했을 때, 입력 필드에 초기값으로 들어갈 텍스트입니다.
  String _pendingInitialReplyText = '';

  // 댓글 리스트에서 각 댓글 사이에 들어가는 구분선 위젯의 수직 패딩입니다.
  int _textInputSession = 0;

  /// 선택된 댓글 ID에서 해시코드를 추출하는 함수입니다.
  int? _selectedHashCode(String? selectedCommentId) {
    if (selectedCommentId == null) return null;
    final parts = selectedCommentId.split('_');
    if (parts.length < 2) return null;
    return int.tryParse(parts.last);
  }

  Comment? _persistedCommentOrNull(Comment? comment) {
    if (comment == null) {
      return null;
    }
    if (comment.id == null || comment.userId == null) {
      return null;
    }
    return comment;
  }

  Future<Comment> _resolvePersistedComment({
    required Comment? directComment,
    required Comment? Function(List<Comment> comments) matcher,
  }) async {
    final persistedDirect = _persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    final commentController = context.read<CommentController>();
    for (var attempt = 0; attempt < _savedCommentLookupAttempts; attempt++) {
      final comments = await commentController.getComments(
        postId: widget.postId,
      );
      final matched = _persistedCommentOrNull(matcher(comments));
      if (matched != null) {
        return matched;
      }
      if (attempt < _savedCommentLookupAttempts - 1) {
        await Future<void>.delayed(_savedCommentLookupDelay);
      }
    }

    throw StateError('저장된 댓글의 id/userId를 확인하지 못했습니다.');
  }

  Comment? _findSavedTextComment({
    required List<Comment> comments,
    required int userId,
    required String text,
    required Comment? replyTarget,
  }) {
    final trimmedText = text.trim();
    final targetReplyUserName = (replyTarget?.nickname ?? '').trim();

    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
        continue;
      }

      final isExpectedType = replyTarget != null
          ? comment.isReply
          : comment.isText;
      if (!isExpectedType) {
        continue;
      }

      if ((comment.text ?? '').trim() != trimmedText) {
        continue;
      }

      if (replyTarget != null &&
          targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      return comment;
    }

    return null;
  }

  Comment? _findSavedAudioReplyComment({
    required List<Comment> comments,
    required int userId,
    required Comment replyTarget,
    required int durationMs,
  }) {
    final targetReplyUserName = (replyTarget.nickname ?? '').trim();

    for (final comment in comments.reversed) {
      if (!comment.isReply || comment.userId != userId) {
        continue;
      }

      if (targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      if ((comment.duration ?? 0) == durationMs) {
        return comment;
      }
    }

    return null;
  }

  Comment? _findSavedMediaReplyComment({
    required List<Comment> comments,
    required int userId,
    required Comment replyTarget,
    required String fileKey,
  }) {
    final targetReplyUserName = (replyTarget.nickname ?? '').trim();

    for (final comment in comments.reversed) {
      if (!comment.isReply || comment.userId != userId) {
        continue;
      }

      if (targetReplyUserName.isNotEmpty &&
          (comment.replyUserName ?? '').trim() != targetReplyUserName) {
        continue;
      }

      if ((comment.fileKey ?? '').trim() == fileKey) {
        return comment;
      }
    }

    return null;
  }

  /// selectedHash를 기반으로 강조 표시할 스레드의 키를 계산하는 함수입니다.
  Comment? _selectedCommentByHash(int? selectedHash) {
    if (selectedHash == null) return null;
    return _comments.cast<Comment?>().firstWhere(
      (comment) => comment?.hashCode == selectedHash,
      orElse: () => null,
    );
  }

  /// selectedHash를 기반으로 강조 표시할 스레드의 키를 계산하는 함수입니다.
  /// selectedHash를 가진 댓글이 대댓글인 경우, 그 부모 댓글을 기준으로 스레드를 강조 표시하기 위한 키를 반환합니다.
  ///
  /// Parameters:
  /// - [selectedHash]: 선택된 댓글의 해시코드입니다. 이 해시코드를 가진 댓글이 강조 표시될 스레드의 기준이 됩니다.
  String? _highlightThreadKey(int? selectedHash) {
    if (_manuallyHighlightedThreadKey != null) {
      return _manuallyHighlightedThreadKey;
    }

    // selectedHash를 가진 댓글을 찾아옵니다.
    final selectedComment = _selectedCommentByHash(selectedHash);
    if (selectedComment == null) return null;

    // 선택된 댓글이 속한 스레드를 강조 표시하기 위한 키를 계산합니다.
    // 대댓글인 경우 부모 댓글을 찾아서 그 댓글을 기준으로 스레드를 펼칠지 말지를 결정합니다.
    final anchorComment = selectedComment.isReply
        ? _findParentComment(selectedComment) ?? selectedComment
        : selectedComment;
    return _commentKeyId(anchorComment);
  }

  /// 특정 댓글이 강조 표시된 스레드에 속하는지 여부를 판단하는 함수입니다.
  /// 댓글이 선택된 댓글과 같은 스레드에 속해있다면 true를 반환합니다.
  ///
  /// Parameters:
  /// - [comment]: 검사할 댓글 객체입니다.
  /// - [anchorKey]: 선택된 댓글이 속한 스레드의 키입니다. 이 키를 기준으로 댓글이 같은 스레드에 속하는지 판단합니다.
  bool _belongsToHighlightedThread(Comment comment, String? anchorKey) {
    if (anchorKey == null) return false;
    if (_commentKeyId(comment) == anchorKey) {
      return true;
    }
    if (!comment.isReply) {
      return false;
    }

    final parentComment = _findParentComment(comment); // 댓글의 부모 댓글을 찾습니다.
    if (parentComment == null) {
      return false;
    }
    // 부모 댓글의 키가 anchorKey와 일치하는지 확인합니다.
    // 이렇게 하면, 선택된 댓글이 대댓글인 경우에도 그 부모 댓글을 기준으로 스레드를 강조 표시할 수 있습니다.
    return _commentKeyId(parentComment) == anchorKey;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _replyDraftController = TextEditingController();
    _replyDraftFocusNode = FocusNode();
    _replyDraftFocusNode.addListener(_handleReplyDraftFocusChanged);
    _comments = widget.comments.toList();
    _expandSelectedReplyParentIfNeeded();

    if (widget.selectedCommentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedComment();
      });
    }
  }

  @override
  void dispose() {
    _replyDraftFocusNode.removeListener(_handleReplyDraftFocusChanged);
    _replyDraftFocusNode.dispose();
    _replyDraftController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 댓글 리스트가 처음 열릴 때, 선택된 댓글이 있으면 해당 댓글로 스크롤하는 함수
  void _scrollToSelectedComment() {
    if (widget.selectedCommentId == null) return;

    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final targetComment = _comments.cast<Comment?>().firstWhere(
      (comment) => comment?.hashCode == targetHash,
      orElse: () => null,
    );
    if (targetComment == null) return;

    _scrollCommentAboveActionBar(targetComment, animated: false);
  }

  void _expandSelectedReplyParentIfNeeded() {
    final targetHash = _selectedHashCode(widget.selectedCommentId);
    if (targetHash == null) return;

    final targetComment = _comments.cast<Comment?>().firstWhere(
      (comment) => comment?.hashCode == targetHash,
      orElse: () => null,
    );
    if (targetComment == null || !targetComment.isReply) return;

    final parentComment = _findParentComment(targetComment);
    if (parentComment == null) return;

    _expandedReplyParentKeys.add(_commentKeyId(parentComment));
  }

  void _showReplyInput({Comment? replyTarget}) {
    if (replyTarget != null &&
        (replyTarget.id == null || replyTarget.userId == null)) {
      _showSnackBar(tr('common.user_info_unavailable'));
      return;
    }

    setState(() {
      _replyTargetComment = replyTarget;
      _attachmentReplyTarget = replyTarget;
      _isReplyDraftArmed = true;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });

    _replyDraftController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_replyDraftFocusNode);
      if (replyTarget != null) {
        _scrollCommentAboveActionBar(replyTarget);
      }
    });
  }

  String _commentKeyId(Comment comment) {
    final idPart = comment.id?.toString() ?? 'hash_${comment.hashCode}';
    return '${comment.type.name}_$idPart';
  }

  GlobalKey _keyForComment(Comment comment) {
    return _commentKeys.putIfAbsent(
      _commentKeyId(comment),
      () => GlobalKey(debugLabel: 'comment_${_commentKeyId(comment)}'),
    );
  }

  Future<void> _scrollCommentAboveActionBar(
    Comment targetComment, {
    bool animated = true,
  }) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final viewportContext = _commentListViewportKey.currentContext;
    final targetContext = _keyForComment(targetComment).currentContext;
    if (viewportContext == null || targetContext == null) {
      return;
    }

    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (viewportBox == null || targetBox == null) {
      return;
    }

    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final targetTopLeft = targetBox.localToGlobal(Offset.zero);
    final viewportBottom = viewportTopLeft.dy + viewportBox.size.height;
    final targetBottom = targetTopLeft.dy + targetBox.size.height;
    final scrollDelta = targetBottom - viewportBottom;

    if (scrollDelta.abs() < 1) {
      return;
    }

    final nextOffset = (_scrollController.offset + scrollDelta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animated) {
      await _scrollController.animateTo(
        nextOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    _scrollController.jumpTo(nextOffset);
  }

  void _handleReplyDraftFocusChanged() {
    if (_replyDraftFocusNode.hasFocus ||
        // 입력 모드로 진입한 상태에서 포커스가 잠시 다른 곳으로 갔다가 다시 돌아오는 경우를 방지하기 위해,
        // 포커스가 사라지는 경우에도 입력 모드를 유지하는 로직입니다.
        _isTextInputMode ||
        // 대댓글 입력 모드로 포커스가 갔는데, 아직 입력된 텍스트가 없는 경우에는 대댓글 입력 모드를 유지합니다.
        !_isReplyDraftArmed ||
        // 대댓글 입력 모드로 포커스가 갔는데, 아직 입력된 텍스트가 없는 경우에는 대댓글 입력 모드를 유지합니다.
        _replyDraftController.text.trim().isNotEmpty) {
      return;
    }

    // 아이콘 탭 시 포커스가 먼저 빠질 수 있어, 다음 프레임까지는 reply 상태를 유지합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _replyDraftFocusNode.hasFocus ||
          _isTextInputMode ||
          _isOpeningAttachmentSheet ||
          !_isReplyDraftArmed ||
          _replyDraftController.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        _replyTargetComment = null;
        _isReplyDraftArmed = false;
      });
    });
  }

  void _handleReplyDraftChanged(String value) {
    if (!_isReplyDraftArmed || _isTextInputMode || value.isEmpty) {
      return;
    }

    final replyTarget = _replyTargetComment;
    _replyDraftFocusNode.unfocus();
    setState(() {
      _pendingInitialReplyText = value;
      _isTextInputMode = true;
      _textInputSession++;
    });
    _replyDraftController.clear();
    if (replyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollCommentAboveActionBar(replyTarget);
      });
    }
  }

  void _hideReplyInput() {
    if (!mounted) {
      return;
    }
    setState(() {
      _replyTargetComment = null;
      _attachmentReplyTarget = null;
      _isReplyDraftArmed = false;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });
    _replyDraftController.clear();
    _replyDraftFocusNode.unfocus();
  }

  Future<void> _submitTextComment(String text) async {
    final currentUser = context.read<UserController>().currentUser;
    if (currentUser == null) {
      _showSnackBar(tr('common.login_required'));
      throw StateError('login_required');
    }

    final replyTarget = _replyTargetComment;
    final result = await context.read<CommentController>().createComment(
      postId: widget.postId,
      userId: currentUser.id,
      parentId: replyTarget?.id ?? 0,
      replyUserId: replyTarget?.userId ?? 0,
      text: text,
      type: replyTarget != null ? CommentType.reply : CommentType.text,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      _showSnackBar(tr('comments.save_failed'));
      throw StateError('comment_save_failed');
    }

    try {
      final savedComment = await _resolvePersistedComment(
        directComment: result.comment,
        matcher: (comments) => _findSavedTextComment(
          comments: comments,
          userId: currentUser.id,
          text: text,
          replyTarget: replyTarget,
        ),
      );
      if (!mounted) {
        return;
      }
      _insertSavedComment(
        savedComment,
        replyTarget: replyTarget,
        currentUserProfileKey: currentUser.profileImageUrlKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
      throw StateError('comment_save_unresolved');
    }
  }

  /// 카메라 아이콘을 탭했을 때 호출되는 함수입니다.
  /// 대댓글 입력 모드가 활성화되어 있고, 답글 대상 댓글이 있는 경우에만 동작합니다.
  Future<void> _handleCameraPressed() async {
    final replyTarget = _replyTargetComment ?? _attachmentReplyTarget;
    if (replyTarget == null) {
      return;
    }

    // 카메라/미디어 첨부 시트 열기 함수입니다.
    // openSheet 콜백에서 시트를 열고, onResult 콜백에서 시트가 반환한 결과를 처리합니다.
    await _openAttachmentSheet<CommentCameraSheetResult>(
      // 카메라 시트를 여는 함수입니다. 녹화가 완료되면 onResult 콜백이 호출됩니다.
      openSheet: () {
        return showModalBottomSheet<CommentCameraSheetResult>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const CommentCameraRecordingBottomSheetWidget(),
        );
      },

      // 카메라 시트에서 결과가 반환되었을 때 호출되는 콜백 함수입니다.
      // 시트에서 반환된 결과를 사용하여 댓글을 서버에 업로드하고, 댓글 리스트에 추가합니다.
      // 여기서 미리 캡처해둔 replyTarget을 사용하여, 시트가 열렸을 때의 답글 대상을 정확히 참조합니다.
      onResult: (result) async {
        await _submitMediaComment(
          replyTarget: replyTarget,
          localFilePath: result.localFilePath,
          isVideo: result.isVideo,
        );
      },
    );
  }

  Future<void> _handleMicPressed() async {
    final replyTarget = _replyTargetComment ?? _attachmentReplyTarget;
    if (replyTarget == null) {
      return;
    }

    //
    await _openAttachmentSheet<CommentAudioSheetResult>(
      // openSheet과 onResult 콜백에서 replyTarget이 변경되는 것을 방지하기 위해,
      // replyTarget을 로컬 변수로 고정합니다.
      openSheet: () {
        // 음성 녹음 시트를 여는 함수입니다. 녹음이 완료되면 onResult 콜백이 호출됩니다.
        return showModalBottomSheet<CommentAudioSheetResult>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const CommentAudioRecordingBottomSheetWidget(),
        );
      },
      onResult: (result) async {
        // 녹음이 완료된 후, 결과를 처리하는 함수입니다. 녹음 결과를 서버에 업로드하고 댓글로 등록합니다.
        // 여기서, 미리 캡처해둔 replyTarget을 사용하여, 녹음이 완료된 시점의 답글 대상을 정확히 참조합니다.
        await _submitAudioComment(
          replyTarget: replyTarget,
          audioPath: result.audioPath,
          waveformData: result.waveformData,
          durationMs: result.durationMs,
        );
      },
    );
  }

  Future<void> _openAttachmentSheet<T>({
    required Future<T?> Function() openSheet,
    required Future<void> Function(T result) onResult,
  }) async {
    if (_isOpeningAttachmentSheet) {
      return;
    }

    _isOpeningAttachmentSheet = true;
    _replyDraftFocusNode.unfocus();

    try {
      final result = await openSheet();
      if (!mounted || result == null) {
        return;
      }
      await onResult(result);
    } finally {
      _isOpeningAttachmentSheet = false;
    }
  }

  Future<void> _submitAudioComment({
    required Comment replyTarget,
    required String audioPath,
    required List<double> waveformData,
    required int durationMs,
  }) async {
    final currentUser = context.read<UserController>().currentUser;
    final mediaController = context.read<MediaController>();
    if (currentUser == null) {
      _showSnackBar(tr('common.login_required'));
      return;
    }

    final trimmedAudioPath = audioPath.trim();
    if (trimmedAudioPath.isEmpty) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final audioFile = File(trimmedAudioPath);
    if (!await audioFile.exists()) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final multipartFile = await mediaController.fileToMultipart(audioFile);
    final audioKey = await mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: currentUser.id,
      postId: widget.postId,
    );

    if (!mounted || audioKey == null || audioKey.isEmpty) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final encodedWaveform = _encodeWaveformForRequest(waveformData);
    final result = await context.read<CommentController>().createComment(
      postId: widget.postId,
      userId: currentUser.id,
      parentId: replyTarget.id ?? 0,
      replyUserId: replyTarget.userId ?? 0,
      audioKey: audioKey,
      waveformData: encodedWaveform,
      duration: durationMs,
      type: CommentType.reply,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    try {
      final savedComment = await _resolvePersistedComment(
        directComment: result.comment,
        matcher: (comments) => _findSavedAudioReplyComment(
          comments: comments,
          userId: currentUser.id,
          replyTarget: replyTarget,
          durationMs: durationMs,
        ),
      );
      if (!mounted) {
        return;
      }
      _insertSavedComment(
        savedComment,
        replyTarget: replyTarget,
        currentUserProfileKey: currentUser.profileImageUrlKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
    }
  }

  Future<void> _submitMediaComment({
    required Comment replyTarget,
    required String localFilePath,
    required bool isVideo,
  }) async {
    final currentUser = context.read<UserController>().currentUser;
    final mediaController = context.read<MediaController>();
    if (currentUser == null) {
      _showSnackBar(tr('common.login_required'));
      return;
    }

    final trimmedPath = localFilePath.trim();
    if (trimmedPath.isEmpty) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final mediaFile = File(trimmedPath);
    if (!await mediaFile.exists()) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final multipartFile = await mediaController.fileToMultipart(mediaFile);
    final mediaType = isVideo ? MediaType.video : MediaType.image;
    final uploadedKeys = await mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: currentUser.id,
      refId: widget.postId,
      usageCount: 1,
    );

    if (!mounted || uploadedKeys.isEmpty || uploadedKeys.first.isEmpty) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    final fileKey = uploadedKeys.first;
    final result = await context.read<CommentController>().createComment(
      postId: widget.postId,
      userId: currentUser.id,
      parentId: replyTarget.id ?? 0,
      replyUserId: replyTarget.userId ?? 0,
      fileKey: fileKey,
      type: CommentType.reply,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      _showSnackBar(tr('comments.save_failed'));
      return;
    }

    try {
      final savedComment = await _resolvePersistedComment(
        directComment: result.comment,
        matcher: (comments) => _findSavedMediaReplyComment(
          comments: comments,
          userId: currentUser.id,
          replyTarget: replyTarget,
          fileKey: fileKey,
        ),
      );
      if (!mounted) {
        return;
      }
      _insertSavedComment(
        savedComment,
        replyTarget: replyTarget,
        currentUserProfileKey: currentUser.profileImageUrlKey,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(tr('comments.save_failed'));
      }
    }
  }

  void _insertSavedComment(
    Comment savedComment, {
    required Comment? replyTarget,
    required String? currentUserProfileKey,
  }) {
    final normalizedComment = _normalizeCommentForThread(
      savedComment,
      replyTarget: replyTarget,
      currentUserProfileKey: currentUserProfileKey,
    );

    final insertIndex = _resolveInsertIndex(replyTarget);
    setState(() {
      if (replyTarget != null) {
        final parentComment = _findParentComment(replyTarget);
        if (parentComment != null) {
          final parentIndex = _indexOfComment(parentComment);
          if (parentIndex >= 0) {
            final currentParent = _comments[parentIndex];
            _comments[parentIndex] = currentParent.copyWith(
              replyCommentCount: (currentParent.replyCommentCount ?? 0) + 1,
            );
            _expandedReplyParentKeys.add(_commentKeyId(currentParent));
          }
        }
      }
      _comments.insert(insertIndex, normalizedComment);
      _replyTargetComment = null;
      _attachmentReplyTarget = null;
      _isReplyDraftArmed = false;
      _isTextInputMode = false;
      _pendingInitialReplyText = '';
    });
    _notifyCommentsUpdated();
  }

  Comment _normalizeCommentForThread(
    Comment comment, {
    required Comment? replyTarget,
    required String? currentUserProfileKey,
  }) {
    final normalizedReplyUserName =
        (comment.replyUserName ?? '').trim().isNotEmpty
        ? comment.replyUserName
        : replyTarget?.nickname;
    final normalizedProfileUrl =
        (comment.userProfileUrl ?? '').trim().isNotEmpty
        ? comment.userProfileUrl
        : currentUserProfileKey;
    final normalizedProfileKey =
        (comment.userProfileKey ?? '').trim().isNotEmpty
        ? comment.userProfileKey
        : currentUserProfileKey;

    return comment.copyWith(
      replyUserName: normalizedReplyUserName,
      userProfileUrl: normalizedProfileUrl,
      userProfileKey: normalizedProfileKey,
      createdAt: comment.createdAt ?? DateTime.now(),
      type: replyTarget != null ? CommentType.reply : comment.type,
    );
  }

  String _encodeWaveformForRequest(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return '';
    }

    final sampled = _sampleWaveformData(waveformData, _maxWaveformSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(4)))
        .toList();
    return jsonEncode(rounded);
  }

  List<double> _sampleWaveformData(List<double> source, int maxLength) {
    if (source.length <= maxLength) {
      return source;
    }

    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
    );
  }

  int _resolveInsertIndex(Comment? replyTarget) {
    if (replyTarget == null) {
      return _comments.length;
    }

    final targetIndex = _comments.indexWhere(
      (comment) =>
          comment.id == replyTarget.id &&
          comment.hashCode == replyTarget.hashCode,
    );
    if (targetIndex < 0) {
      return _comments.length;
    }

    if (replyTarget.isReply) {
      return targetIndex + 1;
    }

    var insertIndex = targetIndex + 1;
    while (insertIndex < _comments.length && _comments[insertIndex].isReply) {
      insertIndex++;
    }
    return insertIndex;
  }

  int _indexOfComment(Comment target) {
    return _comments.indexWhere(
      (comment) =>
          comment.id == target.id && comment.hashCode == target.hashCode,
    );
  }

  Comment? _findParentComment(Comment comment) {
    final targetIndex = _indexOfComment(comment);
    if (targetIndex < 0) return null;
    if (!comment.isReply) return comment;

    for (var index = targetIndex - 1; index >= 0; index--) {
      final candidate = _comments[index];
      if (!candidate.isReply) {
        return candidate;
      }
    }

    return null;
  }

  List<Comment> _visibleComments() {
    final visible = <Comment>[];
    Comment? currentParent;
    var isCurrentParentExpanded = false;

    for (final comment in _comments) {
      if (!comment.isReply) {
        currentParent = comment;
        isCurrentParentExpanded = _expandedReplyParentKeys.contains(
          _commentKeyId(comment),
        );
        visible.add(comment);
        continue;
      }

      if (currentParent == null || isCurrentParentExpanded) {
        visible.add(comment);
      }
    }

    return visible;
  }

  void _showRepliesForComment(Comment comment) {
    // 대댓글인 경우 부모 댓글을 찾아서 그 댓글을 기준으로 스레드를 펼칠지 말지를 결정합니다.
    final parentComment = comment.isReply
        ? _findParentComment(comment)
        : comment;
    if (parentComment == null || !mounted) return;

    // parentKey를 기준으로 대댓글이 펼쳐질지 말지가 결정됩니다.
    final parentKey = _commentKeyId(parentComment);
    setState(() {
      _expandedReplyParentKeys.add(parentKey); // 해당 스레드의 대댓글을 펼칩니다.
      _manuallyHighlightedThreadKey =
          parentKey; // 대댓글이 펼쳐질 때 해당 스레드를 수동으로 강조 표시하도록 설정합니다.
    });
  }

  void _hideRepliesForComment(Comment comment) {
    final parentComment = comment.isReply
        ? _findParentComment(comment)
        : comment;
    if (parentComment == null || !mounted) return;

    final parentKey = _commentKeyId(parentComment);
    setState(() {
      _expandedReplyParentKeys.remove(parentKey);
      if (_manuallyHighlightedThreadKey == parentKey) {
        _manuallyHighlightedThreadKey = null;
      }
    });
  }

  void _showSnackBar(String message) {
    SnackBarUtils.showSnackBar(context, message);
  }

  void _notifyCommentsUpdated() {
    widget.onCommentsUpdated?.call(List<Comment>.unmodifiable(_comments));
  }

  Widget _buildCommentSeparator({
    required Comment current,
    required Comment next,
    required bool currentHighlighted,
    required bool nextHighlighted,
  }) {
    // 다음 항목이 대댓글이면 같은 reply 묶음으로 간주해 선을 숨깁니다.
    if (next.isReply) {
      return Container(
        width: double.infinity,
        height: 15.sp,
        color: currentHighlighted || nextHighlighted
            ? _commentHighlightColor
            : Colors.transparent,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: _commentDividerVerticalPadding.sp,
          color: currentHighlighted
              ? _commentHighlightColor
              : Colors.transparent,
        ),
        const Divider(color: Color(0xFF323232), thickness: 1, height: 1),
        Container(
          width: double.infinity,
          height: _commentDividerVerticalPadding.sp,
          color: nextHighlighted ? _commentHighlightColor : Colors.transparent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * _sheetHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        width: double.infinity,
        height: sheetHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF1c1c1c),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24.8),
            topRight: Radius.circular(24.8),
          ),
        ),
        padding: EdgeInsets.only(bottom: 10.sp),
        child: Column(
          children: [
            SizedBox(height: 20.sp),
            Text(
              tr('comments.title', context: context),
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 18.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 15.sp),
            _buildCommentList(),
            //SizedBox(height: 10.sp),
            _buildCommentActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    final selectedHash = _selectedHashCode(
      widget.selectedCommentId,
    ); // widget.selectedCommentId에서 해시코드를 추출합니다.

    // 선택된 댓글이 속한 스레드를 강조 표시하기 위한 키를 계산합니다.
    final highlightedThreadKey = _highlightThreadKey(
      selectedHash,
    ); // selectedHash를 기반으로 강조 표시할 스레드의 키를 계산합니다.
    final visibleComments = _visibleComments();
    return Expanded(
      child: Container(
        key: _commentListViewportKey,
        child: _comments.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Text(
                            tr('comments.empty', context: context),
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 16.sp,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : ListView.separated(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                primary: false,
                itemCount: visibleComments.length,
                separatorBuilder: (_, index) {
                  final current = visibleComments[index];
                  final next = visibleComments[index + 1];
                  return _buildCommentSeparator(
                    current: current,
                    next: next,
                    currentHighlighted: _belongsToHighlightedThread(
                      current,
                      highlightedThreadKey,
                    ),
                    nextHighlighted: _belongsToHighlightedThread(
                      next,
                      highlightedThreadKey,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final comment = visibleComments[index];
                  final isHighlighted = _belongsToHighlightedThread(
                    comment,
                    highlightedThreadKey,
                  );
                  return KeyedSubtree(
                    key: _keyForComment(comment),
                    child: ApiCommentRow(
                      comment: comment,
                      isHighlighted: isHighlighted,
                      onReplyTap: (target) =>
                          _showReplyInput(replyTarget: target),
                      showHideRepliesButton:
                          !comment.isReply &&
                          (comment.replyCommentCount ?? 0) > 0 &&
                          _expandedReplyParentKeys.contains(
                            _commentKeyId(comment),
                          ),
                      showViewMoreRepliesButton:
                          !comment.isReply &&
                          (comment.replyCommentCount ?? 0) > 0 &&
                          !_expandedReplyParentKeys.contains(
                            _commentKeyId(comment),
                          ),
                      onHideRepliesTap: _hideRepliesForComment,
                      onViewMoreRepliesTap: _showRepliesForComment,
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// CommentListSheet 내부에 있는 댓글 추가 액션 바
  Widget _buildCommentActionBar() {
    return Center(
      child: SizedBox(
        height: 52.sp,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isTextInputMode
              ? KeyedSubtree(
                  key: ValueKey(
                    'reply_input_${_replyTargetComment?.id ?? 0}_$_textInputSession',
                  ),
                  child: CommentTextInputWidget(
                    initialText: _pendingInitialReplyText,
                    onSubmitText: _submitTextComment,
                    onEditingCancelled: _hideReplyInput,
                    hintText: tr('comments.add_comment'),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('comment_action_bar'),
                  child: Container(
                    width: 353.sp,
                    height: 46.sp,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0B),
                      borderRadius: BorderRadius.circular(52.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10.sp),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _handleCameraPressed,
                          padding: EdgeInsets.zero,
                          icon: Container(
                            width: 32.sp,
                            height: 32.sp,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF323232),
                              shape: const CircleBorder(),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/camera_mode.png',
                                width: (17.78).sp,
                                height: 16.sp,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.sp),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IgnorePointer(
                              ignoring: !_isReplyDraftArmed,
                              child: TextField(
                                controller: _replyDraftController,
                                focusNode: _replyDraftFocusNode,
                                autofocus: false,
                                minLines: 1,
                                maxLines: 1,
                                onChanged: _handleReplyDraftChanged,
                                onTapOutside: (_) =>
                                    FocusScope.of(context).unfocus(),
                                style: TextStyle(
                                  color: const Color(0xFFF8F8F8),
                                  fontSize: 16.sp,
                                  fontFamily: 'Pretendard Variable',
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -1.14,
                                ),
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: tr('comments.add_comment'),
                                  hintStyle: TextStyle(
                                    color: const Color(0xFFF8F8F8),
                                    fontSize: 16.sp,
                                    fontFamily: 'Pretendard Variable',
                                    fontWeight: FontWeight.w200,
                                    letterSpacing: -1.14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _handleMicPressed,
                          padding: EdgeInsets.zero,
                          icon: Image.asset(
                            'assets/record_icon.png',
                            width: 36.sp,
                            height: 36.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
