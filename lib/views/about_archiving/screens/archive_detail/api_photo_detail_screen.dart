import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../api/models/post.dart';
import '../../../../api/models/comment.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/comment_controller.dart';
import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/audio_controller.dart';
import '../../../../utils/position_converter.dart';
import '../../../../utils/snackbar_utils.dart';
import '../../../common_widget/api_photo/api_photo_card_widget.dart';
import '../../../common_widget/about_comment/pending_api_voice_comment.dart';
import '../../../common_widget/report/report_bottom_sheet.dart';
import '../../../../api/models/friend.dart';

/// API 기반 사진 상세 화면
///
/// Firebase 버전의 PhotoDetailScreen과 동일한 디자인을 유지하면서
/// REST API와 공통 위젯을 사용합니다.
class ApiPhotoDetailScreen extends StatefulWidget {
  final List<Post> allPosts;
  final int initialIndex;
  final String categoryName;
  final int categoryId;
  final bool singlePostMode;

  const ApiPhotoDetailScreen({
    super.key,
    required this.allPosts,
    required this.initialIndex,
    required this.categoryName,
    required this.categoryId,
    this.singlePostMode = false,
  });

  @override
  State<ApiPhotoDetailScreen> createState() => _ApiPhotoDetailScreenState();
}

class _ApiPhotoDetailScreenState extends State<ApiPhotoDetailScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  late List<Post> _posts;
  late final AudioController _audioController;

  final Set<int> _deletedPostIds =
      <int>{}; // 삭제된 게시물 ID 추적 --> 상위 위젯에 전달하기 위해 사용됩니다.
  final Set<int> _deletingPostIds = <int>{};
  bool _allowPopWithDeletionResult = false;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;

  // 컨트롤러
  UserController? _userController;
  FriendController? _friendController;
  VoidCallback? _friendListener;

  // 상태 맵 (Firebase 버전과 동일한 구조)
  final Map<int, List<Comment>> _postComments = {};
  final Map<int, String?> _selectedEmojisByPostId = {}; // postId별 내가 선택한 이모지
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<int, PendingApiCommentDraft> _pendingCommentDrafts = {};
  final Map<int, PendingApiCommentMarker> _pendingCommentMarkers = {};
  final Map<int, String> _resolvedAudioUrls = {};

  String? _emojiFromId(int? emojiId) {
    switch (emojiId) {
      case 0:
        return '😀';
      case 1:
        return '😍';
      case 2:
        return '😭';
      case 3:
        return '😡';
    }
    return null;
  }

  String? _selectedEmojiFromComments({
    required List<Comment> comments,
    required String currentUserNickname,
  }) {
    for (final comment in comments.reversed) {
      if (comment.emojiId == null || comment.emojiId == 0) continue;
      if (comment.nickname != currentUserNickname) continue;
      return _emojiFromId(comment.emojiId);
    }
    return null;
  }

  void _setSelectedEmoji(int postId, String? emoji) {
    if (!mounted) return;
    setState(() {
      if (emoji == null) {
        _selectedEmojisByPostId.remove(postId);
      } else {
        _selectedEmojisByPostId[postId] = emoji;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _posts = List<Post>.from(
      widget.allPosts,
    ); // 자식 위젯에서 부모가 건네준 allPosts 수정을 방지하기 위해서, 복사본 생성
    _pageController = PageController(initialPage: _currentIndex);
    _audioController = AudioController();
    _userController = Provider.of<UserController>(context, listen: false);
    _friendController = Provider.of<FriendController>(context, listen: false);
    if (!widget.singlePostMode) {
      _friendListener = () {
        if (!mounted) return;
        unawaited(_refreshPostsForBlockStatus());
      };
      _friendController?.addListener(_friendListener!);
    }
    _loadUserProfileImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 초기 댓글 로드
      _loadCommentsForPost(_posts[_currentIndex].id);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stopAudio();
    _audioController.dispose();
    if (_friendListener != null) {
      _friendController?.removeListener(_friendListener!);
      _friendListener = null;
    }
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  Future<void> _refreshPostsForBlockStatus() async {
    if (widget.singlePostMode) {
      return;
    }
    if (!mounted) return;
    final userController = _userController ?? context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) return;

    final postController = context.read<PostController>();
    final friendController =
        _friendController ?? context.read<FriendController>();

    final posts = await postController.getPostsByCategory(
      categoryId: widget.categoryId,
      userId: currentUser.id,
      notificationId: null,
    );

    final blockedUsers = await friendController.getAllFriends(
      userId: currentUser.id,
      status: FriendStatus.blocked,
    );
    final blockedIds = blockedUsers.map((user) => user.userId).toSet();
    final filteredPosts = posts
        .where((post) => !blockedIds.contains(post.nickName))
        .toList(growable: false);

    if (!mounted) return;
    if (filteredPosts.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final currentPostId = _posts.isNotEmpty ? _posts[_currentIndex].id : null;
    var nextIndex = 0;
    if (currentPostId != null) {
      final foundIndex = filteredPosts.indexWhere(
        (post) => post.id == currentPostId,
      );
      nextIndex = foundIndex >= 0 ? foundIndex : 0;
    }

    setState(() {
      _posts = filteredPosts;
      _currentIndex = nextIndex;
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_pageController.hasClients) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    _loadUserProfileImage();
    _loadCommentsForPost(_posts[_currentIndex].id);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final allowSystemGesturePopWithDeletion =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final shouldBlockPopForDeletionResult =
        _deletedPostIds.isNotEmpty &&
        !_allowPopWithDeletionResult &&
        !allowSystemGesturePopWithDeletion;

    return ChangeNotifierProvider<AudioController>.value(
      value: _audioController,
      child: PopScope(
        canPop: !shouldBlockPopForDeletionResult,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_deletedPostIds.isEmpty) return;
          _popWithDeletionResult();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.black,
            title: Text(
              widget.categoryName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              // 다운로드 버튼 (미디어가 있는 게시물에서만 표시)
              if (_posts.isNotEmpty && _posts[_currentIndex].hasMedia)
                Padding(
                  padding: EdgeInsets.only(right: 23.w),
                  child: IconButton(
                    onPressed: _downloadPhoto,
                    icon: Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: _posts.length,
            scrollDirection: Axis.vertical,
            clipBehavior: Clip.none,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final post = _posts[index];
              final currentUserId = _userController?.currentUser?.userId;
              final isOwner = currentUserId == post.nickName;

              // 사용자 캐시 채우기
              if (!_userProfileImages.containsKey(post.nickName)) {
                _userProfileImages[post.nickName] = _userProfileImageUrl;
                _profileLoadingStates[post.nickName] = _isLoadingProfile;
                _userNames[post.nickName] = _userName;
              }

              // post 사진 카드 위젯 반환
              // post 사진, 카테고리 이름, 카테고리 ID 등 전달
              return ApiPhotoCardWidget(
                post: post,

                // APICategoryPhotosScreen에서 받아온 categoryName을 전달합니다.
                categoryName: widget.categoryName,

                // APICategoryPhotosScreen에서 받아온 categoryId를 전달합니다.
                categoryId: widget.categoryId,
                index: index,
                isOwner: isOwner,
                isArchive: true,
                isCategory: true,
                selectedEmoji:
                    _selectedEmojisByPostId[post.id], // postId별 선택값 표시
                onEmojiSelected: (emoji) => _setSelectedEmoji(post.id, emoji),
                postComments: _postComments,
                pendingCommentDrafts: _pendingCommentDrafts,
                pendingVoiceComments: _pendingCommentMarkers,
                onToggleAudio: _toggleAudio,
                onTextCommentCompleted: (postId, text) async {
                  await _onTextCommentCreated(postId, text);
                },
                onAudioCommentCompleted: _onAudioCommentCompleted,
                onMediaCommentCompleted: _onMediaCommentCompleted,
                onProfileImageDragged: (postId, absolutePosition) {
                  _onProfileImageDragged(postId, absolutePosition);
                },
                onCommentSaveProgress: _onCommentSaveProgress,
                onCommentSaveSuccess: _onCommentSaveSuccess,
                onCommentSaveFailure: _onCommentSaveFailure,
                onDeletePressed: () => _deletePost(post),
                onCommentsReloadRequested: _loadCommentsForPost,
                onReportSubmitted: _saveReportToFirebase,
              );
            },
          ),
        ),
      ),
    );
  }

  // ================= 로직 =================

  Future<void> _saveReportToFirebase(Post post, ReportResult report) async {
    final currentUser = _userController?.currentUser;
    final detail = report.detail?.trim();
    final data = <String, dynamic>{
      'postId': post.id,
      'postNickName': post.nickName,
      'categoryId': widget.categoryId,
      'categoryName': widget.categoryName,
      'reason': report.reason,
      'detail': (detail == null || detail.isEmpty) ? null : detail,
      'reporterUserId': currentUser?.id,
      'reporterNickName': currentUser?.userId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('post_reports').add(data);
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        '신고가 접수되었습니다. 신고 내용을 관리자가 확인 후, 판단 후에 처리하도록 하겠습니다.',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(context, '신고 접수에 실패했습니다.');
    }
  }

  /// 페이지 변경 시 처리
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio();
    _loadUserProfileImage();
    _loadCommentsForPost(_posts[index].id);
  }

  /// 현재 게시물 작성자의 프로필 이미지 로드 (서버에서 제공하는 URL 직접 사용)
  void _loadUserProfileImage() {
    final currentPost = _posts[_currentIndex];
    if (!mounted) return;
    setState(() {
      _userProfileImageUrl = currentPost.userProfileImageUrl ?? '';
      _userName = currentPost.nickName;
      _isLoadingProfile = false;
      _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
      _profileLoadingStates[currentPost.nickName] = false;
      _userNames[currentPost.nickName] = _userName;
    });
  }

  /// 게시물의 댓글 로드
  Future<void> _loadCommentsForPost(int postId) async {
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final comments = await commentController.getComments(postId: postId);

      if (!mounted) return;

      final currentUserId = _userController?.currentUser?.userId;
      _handleCommentsUpdate(postId, currentUserId, comments);
    } catch (e) {
      debugPrint('❌ 댓글 로드 실패: $e');
    }
  }

  /// 댓글 목록 업데이트 처리
  void _handleCommentsUpdate(
    int postId,
    String? currentUserId,
    List<Comment> comments,
  ) {
    if (!mounted) return;

    setState(() {
      _postComments[postId] = comments;

      // 서버 댓글을 바탕으로, 내 이모지 선택값을 복원합니다(있을 때만 덮어쓰기).
      if (currentUserId != null) {
        final selected = _selectedEmojiFromComments(
          comments: comments,
          currentUserNickname: currentUserId,
        );
        if (selected != null) {
          _selectedEmojisByPostId[postId] = selected;
        }
      }
    });
  }

  /// 프로필 이미지 드래그 시 위치 업데이트 처리
  ///
  /// Parameters:
  /// - [postId]: 프로필 이미지가 드래그된 게시물 ID
  /// - [absolutePosition]: 드래그된 절대 위치
  void _onProfileImageDragged(int postId, Offset absolutePosition) {
    // 표시 프레임(354x500)과 동일한 좌표계를 사용해 위치를 변환합니다.
    final imageSize = Size(354.w, 500.h);
    // 포인터 끝점 기준 좌표를 상대 위치로 변환
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    final draft = _pendingCommentDrafts[postId];
    if (draft == null) return;

    setState(() {
      final previousProgress = _pendingCommentMarkers[postId]?.progress;
      _pendingCommentMarkers[postId] = (
        relativePosition: relativePosition,
        profileImageUrlKey: draft.profileImageUrlKey,
        progress: previousProgress,
      );
    });
  }

  /// 오디오 토글 처리
  ///
  /// Parameters:
  ///   - [post]: 오디오 토글할 게시물 객체
  Future<void> _toggleAudio(Post post) async {
    if (!post.hasAudio) return;
    final audioKey = post.audioUrl;
    if (audioKey == null || audioKey.isEmpty) return;
    try {
      var resolved = audioKey;
      final uri = Uri.tryParse(audioKey);
      if (uri == null || !uri.hasScheme) {
        final mediaController = context.read<MediaController>();
        resolved = await mediaController.getPresignedUrl(audioKey) ?? '';
      }
      if (resolved.isEmpty) return;
      _resolvedAudioUrls[post.id] = resolved;
      await _audioController.togglePlayPause(resolved);
    } catch (e) {
      debugPrint('오디오 토글 실패: $e');
    }
  }

  /// 텍스트 댓글 생성 처리
  ///
  /// Parameters:
  ///   - [postId]: 댓글이 생성될 게시물 ID
  /// - [text]: 생성할 텍스트 댓글 내용
  Future<void> _onTextCommentCreated(int postId, String text) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      // 임시 댓글 데이터에 추가
      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingCommentDrafts[postId] = (
        isTextComment: true,
        text: text,
        audioPath: null,
        mediaPath: null,
        isVideo: null,
        waveformData: null,
        duration: null,
        recorderUserId: userId,
        profileImageUrlKey: currentUserProfileImageUrl,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('텍스트 댓글 임시 저장 실패: $e');
    }
  }

  Future<void> _onAudioCommentCompleted(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  ) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingCommentDrafts[postId] = (
        isTextComment: false,
        text: null,
        audioPath: audioPath,
        mediaPath: null,
        isVideo: null,
        waveformData: waveformData,
        duration: durationMs,
        recorderUserId: userId,
        profileImageUrlKey: currentUserProfileImageUrl,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('음성 댓글 임시 저장 실패: $e');
    }
  }

  Future<void> _onMediaCommentCompleted(
    int postId,
    String localFilePath,
    bool isVideo,
  ) async {
    try {
      final userId = _userController?.currentUser?.id;
      if (userId == null) return;

      final currentUserProfileImageUrl =
          _userController?.currentUser?.profileImageUrlKey;

      _pendingCommentDrafts[postId] = (
        isTextComment: false,
        text: null,
        audioPath: null,
        mediaPath: localFilePath,
        isVideo: isVideo,
        waveformData: null,
        duration: null,
        recorderUserId: userId,
        profileImageUrlKey: currentUserProfileImageUrl,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('미디어 댓글 임시 저장 실패: $e');
    }
  }

  void _updatePendingProgress(int postId, double progress) {
    final marker = _pendingCommentMarkers[postId];
    if (marker == null) return;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    if (!mounted) return;
    setState(() {
      _pendingCommentMarkers[postId] = (
        relativePosition: marker.relativePosition,
        profileImageUrlKey: marker.profileImageUrlKey,
        progress: clamped,
      );
    });
  }

  void _onCommentSaveProgress(int postId, double progress) {
    _updatePendingProgress(postId, progress);
  }

  void _onCommentSaveSuccess(int postId, Comment comment) {
    if (!mounted) return;
    setState(() {
      final updatedList = List<Comment>.from(
        _postComments[postId] ?? const <Comment>[],
      )..add(comment);
      _postComments[postId] = updatedList;
      _pendingCommentDrafts.remove(postId);
      _pendingCommentMarkers.remove(postId);
    });
  }

  void _onCommentSaveFailure(int postId, Object error) {
    debugPrint('댓글 저장 실패(postId: $postId): $error');
    final marker = _pendingCommentMarkers[postId];
    if (marker == null) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingCommentMarkers[postId] = (
        relativePosition: marker.relativePosition,
        profileImageUrlKey: marker.profileImageUrlKey,
        progress: null,
      );
    });
  }

  // 게시물 삭제 처리
  Future<void> _deletePost(Post post) async {
    if (_deletingPostIds.contains(post.id)) return;
    _deletingPostIds.add(post.id);
    try {
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      debugPrint("사진 삭제 시도: postId=${post.id}");

      // MoreMenuButton의 '사진 삭제' 바텀시트에서 이미 확인을 받았으므로,
      // 여기서는 추가 다이얼로그 없이 바로 상태를 DELETED로 변경합니다.
      final success = await postController.setPostStatus(
        postId: post.id,
        postStatus: PostStatus.deleted,
      );

      if (!mounted) return;
      if (success) {
        _deletedPostIds.add(post.id);
        _showSnackBar(tr('archive.photo_deleted', context: context));

        // 삭제 후 처리
        _handleSuccessfulDeletion(post);

        final userId = _userController?.currentUser?.id;
        if (userId != null) {
          unawaited(
            Provider.of<api_category.CategoryController>(
              context,
              listen: false,
            ).loadCategories(userId, forceReload: true),
          );
        }
      } else {
        _showSnackBar(tr('archive.delete_error', context: context));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        tr(
          'archive.delete_error_with_reason',
          context: context,
          namedArgs: {'error': e.toString()},
        ),
      );
      debugPrint('사진 삭제 실패: $e');
    } finally {
      _deletingPostIds.remove(post.id);
    }
  }

  void _popWithDeletionResult() {
    if (_allowPopWithDeletionResult) return;
    setState(() => _allowPopWithDeletionResult = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(_deletedPostIds.toList(growable: false));
    });
  }

  /// 게시물 삭제 후, 해당 게시물과 관련된 상태를 정리하는 함수
  ///
  /// Parameters:
  /// - [postId]: 삭제된 게시물 ID
  /// - [nickName]: 삭제된 게시물 작성자의 닉네임 (사용자 캐시 정리를 위해 필요)
  void _clearPostScopedState(int postId, {required String nickName}) {
    _postComments.remove(postId);
    _selectedEmojisByPostId.remove(postId);
    _pendingCommentDrafts.remove(postId);
    _pendingCommentMarkers.remove(postId);
    _resolvedAudioUrls.remove(postId);

    final hasOtherPostsByNickname = _posts.any(
      (existingPost) =>
          existingPost.id != postId && existingPost.nickName == nickName,
    );
    if (!hasOtherPostsByNickname) {
      _userProfileImages.remove(nickName);
      _profileLoadingStates.remove(nickName);
      _userNames.remove(nickName);
    }
  }

  // 삭제 후 상태 업데이트 처리
  void _handleSuccessfulDeletion(Post post) {
    _clearPostScopedState(post.id, nickName: post.nickName);

    if (_posts.length <= 1) {
      if (_deletedPostIds.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _popWithDeletionResult();
      }
      return;
    }
    setState(() {
      // 현재 인덱스 조정
      _posts.removeWhere((p) => p.id == post.id);
      if (_currentIndex >= _posts.length) {
        _currentIndex = _posts.length - 1;
      }
    });

    if (_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_pageController.hasClients) return;
        if (_currentIndex < 0 || _currentIndex >= _posts.length) return;
        _pageController.jumpToPage(_currentIndex);
      });
    }

    // profile 이미지 및 댓글 재로딩
    _loadUserProfileImage();
    _loadCommentsForPost(_posts[_currentIndex].id);
  }

  Future<void> _stopAudio() async {
    await _audioController.stopRealtimeAudio();
  }

  /// 미디어(사진/비디오) 다운로드 처리
  Future<void> _downloadPhoto() async {
    try {
      final currentPost = _posts[_currentIndex];
      final mediaUrl = currentPost.postFileUrl;

      if (mediaUrl == null || mediaUrl.isEmpty) {
        _showSnackBar('다운로드할 미디어가 없습니다.');
        return;
      }

      final isVideo = currentPost.isVideo;

      // 미디어 다운로드
      final response = await http.get(Uri.parse(mediaUrl));

      if (response.statusCode != 200) {
        _showSnackBar('다운로드에 실패했습니다.');
        return;
      }

      final Uint8List bytes = response.bodyBytes;

      if (isVideo) {
        // 비디오의 경우: 임시 파일로 저장 후 갤러리에 저장
        final tempDir = await getTemporaryDirectory();
        final fileName = "SOI_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);

        await Gal.putVideo(tempFile.path);

        // 임시 파일 삭제
        try {
          await tempFile.delete();
        } catch (_) {}
      } else {
        // 이미지의 경우: 바로 저장
        await Gal.putImageBytes(bytes);
      }

      _showSnackBar('갤러리에 저장되었습니다.');
    } catch (e) {
      debugPrint('다운로드 실패: $e');
      _showSnackBar('다운로드 중 오류가 발생했습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }
}
