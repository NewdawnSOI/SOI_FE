import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
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
import '../../../common_widget/photo/photo_card_widget.dart';
import '../../../common_widget/photo/user_info_widget.dart';
import '../../../common_widget/about_comment/comment_for_pending.dart';
import '../../../common_widget/about_comment/comment_input_widget.dart';
import '../../../common_widget/about_comment/comment_list_bottom_sheet.dart';
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
  int _profileLoadGeneration = 0;

  // 컨트롤러
  UserController? _userController;
  FriendController? _friendController;
  VoidCallback? _friendListener;
  int _lastBlockedFriendsRevision = 0;

  // 상태 맵 (Firebase 버전과 동일한 구조)
  final Map<int, String?> _selectedEmojisByPostId = {}; // postId별 내가 선택한 이모지
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<int, PendingApiCommentDraft> _pendingCommentDrafts = {};
  final Map<int, PendingApiCommentMarker> _pendingCommentMarkers = {};
  final Map<int, String> _resolvedAudioUrls = {};
  final Map<int, Future<void>> _inFlightTagCommentLoads = {};
  final Map<int, Future<List<Comment>>> _inFlightFullCommentLoads = {};
  bool _isTextFieldFocused = false;

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
    _lastBlockedFriendsRevision =
        _friendController?.blockedFriendsRevision ?? 0;
    if (!widget.singlePostMode) {
      _friendListener = () {
        final friendController = _friendController;
        if (!mounted || friendController == null) return;
        final nextRevision = friendController.blockedFriendsRevision;
        if (nextRevision == _lastBlockedFriendsRevision) {
          return;
        }
        _lastBlockedFriendsRevision = nextRevision;
        unawaited(_refreshPostsForBlockStatus());
      };
      _friendController?.addListener(_friendListener!);
    }
    unawaited(_loadUserProfileImage());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 초기 댓글 로드
      _loadTagCommentsForPost(_posts[_currentIndex].id);
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

    unawaited(_loadUserProfileImage());
    _loadTagCommentsForPost(_posts[_currentIndex].id);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = _isTextFieldFocused || keyboardInset > 0;
    final composerBottomInset = isKeyboardVisible ? keyboardInset + 10.0 : 55.0;

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
          resizeToAvoidBottomInset: false,
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
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 사진/영상 부분만 위아래로 스크롤
                  SizedBox(
                    height: 500.h,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _posts.length,
                      scrollDirection: Axis.vertical,
                      clipBehavior: Clip.hardEdge,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        final currentUserId =
                            _userController?.currentUser?.userId;
                        final isOwner = currentUserId == post.nickName;

                        // 사용자 캐시 채우기
                        if (!_userProfileImages.containsKey(post.nickName)) {
                          _userProfileImages[post.nickName] =
                              _userProfileImageUrl;
                          _profileLoadingStates[post.nickName] =
                              _isLoadingProfile;
                          _userNames[post.nickName] = _userName;
                        }

                        return ApiPhotoCardWidget(
                          key: ValueKey(post.id),
                          post: post,
                          categoryName: widget.categoryName,
                          categoryId: widget.categoryId,
                          index: index,
                          isOwner: isOwner,
                          isArchive: true,
                          isCategory: true,
                          displayOnly: true,
                          selectedEmoji: _selectedEmojisByPostId[post.id],
                          onEmojiSelected: (emoji) =>
                              _setSelectedEmoji(post.id, emoji),
                          pendingCommentDrafts: _pendingCommentDrafts,
                          pendingVoiceComments: _pendingCommentMarkers,
                          onToggleAudio: _toggleAudio,
                          onProfileImageDragged: (postId, absolutePosition) {
                            _onProfileImageDragged(postId, absolutePosition);
                          },
                          onCommentsReloadRequested: _reloadCommentsForPost,
                          onLoadFullComments: _loadFullCommentsForPost,
                        );
                      },
                    ),
                  ),

                  // 현재 게시물의 작성자 정보 (화면에 고정)
                  if (_posts.isNotEmpty && _currentIndex < _posts.length) ...[
                    SizedBox(height: 12.h),
                    Builder(
                      builder: (context) {
                        final post = _posts[_currentIndex];
                        final currentUserId =
                            _userController?.currentUser?.userId;
                        final isOwner = currentUserId == post.nickName;
                        return ApiUserInfoWidget(
                          post: post,
                          isCurrentUserPost: isOwner,
                          onDeletePressed: () => _deletePost(post),
                          onCommentPressed: () {
                            final comments = _initialSheetCommentsForPost(
                              post.id,
                            );
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) {
                                return ChangeNotifierProvider(
                                  create: (_) => AudioController(),
                                  child: ApiVoiceCommentListSheet(
                                    postId: post.id,
                                    initialComments: comments,
                                    loadFullComments: _loadFullCommentsForPost,
                                    onCommentsUpdated: (updatedComments) {
                                      if (!mounted) return;
                                      setState(() {
                                        _replaceCommentCaches(
                                          post.id,
                                          updatedComments,
                                        );
                                      });
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 10.h),
                    // 댓글 입력창 공간 확보
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: isKeyboardVisible ? 0 : 90.h,
                    ),
                  ],
                ],
              ),

              // 댓글 입력창 (화면에 고정)
              // 키보드가 올라오면 viewInsets.bottom 만큼 위로 올라가고,
              // 키보드가 없으면 탭바 위 55px에 위치합니다.
              if (_posts.isNotEmpty && _currentIndex < _posts.length)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: composerBottomInset),
                    child: CommentInputWidget(
                      postId: _posts[_currentIndex].id,
                      pendingCommentDrafts: _pendingCommentDrafts,
                      onTextCommentCompleted: (postId, text) async {
                        await _onTextCommentCreated(postId, text);
                      },
                      onAudioCommentCompleted: _onAudioCommentCompleted,
                      onMediaCommentCompleted: _onMediaCommentCompleted,
                      resolveDropRelativePosition: (postId) =>
                          _pendingCommentMarkers[postId]?.relativePosition,
                      onCommentSaveProgress: _onCommentSaveProgress,
                      onCommentSaveSuccess: _onCommentSaveSuccess,
                      onCommentSaveFailure: _onCommentSaveFailure,
                      onTextFieldFocusChanged: (isFocused) {
                        setState(() {
                          _isTextFieldFocused = isFocused;
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 페이지 변경 시 처리
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio();
    unawaited(_loadUserProfileImage());
    _loadTagCommentsForPost(_posts[index].id);
  }

  /// 서버가 내려준 URL을 즉시 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 미디어/프로필 key를 캐시 식별과 presigned URL 재발급 기준으로 정규화합니다.
  String? _normalizeImageKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 상세 화면 작성자 프로필은 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateProfileImageUrl(Post post) {
    final immediateUrl = _normalizeImageUrl(post.userProfileImageUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final profileKey = _normalizeImageKey(post.userProfileImageKey);
    if (profileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(profileKey);
    } catch (_) {
      return null;
    }
  }

  /// 상세 화면 미디어는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateMediaUrl(Post post) {
    final immediateUrl = _normalizeImageUrl(post.postFileUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final mediaKey = _normalizeImageKey(post.postFileKey);
    if (mediaKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(mediaKey);
    } catch (_) {
      return null;
    }
  }

  /// 현재 게시물 작성자 프로필은 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _loadUserProfileImage() async {
    final currentPost = _posts[_currentIndex];
    final requestId = ++_profileLoadGeneration;
    final immediateUrl = _resolveImmediateProfileImageUrl(currentPost);
    final profileKey = _normalizeImageKey(currentPost.userProfileImageKey);

    if (!mounted) return;
    setState(() {
      _userProfileImageUrl = immediateUrl ?? '';
      _userName = currentPost.nickName;
      _isLoadingProfile = immediateUrl == null && profileKey != null;
      _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
      _profileLoadingStates[currentPost.nickName] = _isLoadingProfile;
      _userNames[currentPost.nickName] = _userName;
    });

    if (profileKey == null) {
      return;
    }

    try {
      final resolvedUrl = _normalizeImageUrl(
        await context.read<MediaController>().getPresignedUrl(profileKey),
      );
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      setState(() {
        _userProfileImageUrl = resolvedUrl ?? immediateUrl ?? '';
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = _userName;
      });
    } catch (_) {
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      setState(() {
        _userProfileImageUrl = immediateUrl ?? '';
        _userName = currentPost.nickName;
        _isLoadingProfile = false;
        _userProfileImages[currentPost.nickName] = _userProfileImageUrl;
        _profileLoadingStates[currentPost.nickName] = false;
        _userNames[currentPost.nickName] = _userName;
      });
    }
  }

  /// 다운로드는 즉시 URL을 우선 사용하고, 없을 때만 key로 최신 presigned URL을 발급받아 진행합니다.
  Future<String?> _resolveMediaUrl(Post post) async {
    final immediateUrl = _resolveImmediateMediaUrl(post);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final mediaKey = _normalizeImageKey(post.postFileKey);
    if (mediaKey == null) {
      return null;
    }

    return _normalizeImageUrl(
      await context.read<MediaController>().getPresignedUrl(mediaKey),
    );
  }

  /// 상세 화면은 overlay용 tag cache를 우선 사용하고 full thread는 시트를 열 때만 가져옵니다.
  Future<void> _loadTagCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    final commentController = context.read<CommentController>();
    if (!forceReload) {
      if (commentController.peekTagCommentsCache(postId: postId) != null) {
        return;
      }
      final inFlight = _inFlightTagCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        await commentController.getTagComments(
          postId: postId,
          forceReload: forceReload,
        );
      } catch (error) {
        debugPrint('태그 댓글 로드 실패(postId: $postId): $error');
      }
    }();

    _inFlightTagCommentLoads[postId] = future;
    try {
      await future;
    } finally {
      final registered = _inFlightTagCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightTagCommentLoads.remove(postId);
      }
    }
  }

  /// 댓글시트는 full thread를 캐시해 재오픈 시 네트워크 비용을 줄입니다.
  Future<List<Comment>> _loadFullCommentsForPost(
    int postId, {
    bool forceReload = false,
  }) async {
    final commentController = context.read<CommentController>();
    if (!forceReload) {
      final cached = commentController.peekCommentsCache(postId: postId);
      if (cached != null) {
        return cached;
      }
      final inFlight = _inFlightFullCommentLoads[postId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = () async {
      try {
        final comments = await commentController.getComments(
          postId: postId,
          forceReload: forceReload,
        );
        if (!mounted) {
          return comments;
        }

        setState(() {
          _replaceCommentCaches(postId, comments);
        });
        return comments;
      } catch (error) {
        debugPrint('전체 댓글 로드 실패(postId: $postId): $error');
        return commentController.peekCommentsCache(postId: postId) ??
            const <Comment>[];
      }
    }();

    _inFlightFullCommentLoads[postId] = future;
    try {
      return await future;
    } finally {
      final registered = _inFlightFullCommentLoads[postId];
      if (identical(registered, future)) {
        _inFlightFullCommentLoads.remove(postId);
      }
    }
  }

  /// overlay 삭제 후에는 이미 가진 cache 범위에 맞춰 tag/full 중 필요한 조회만 다시 수행합니다.
  Future<void> _reloadCommentsForPost(int postId) async {
    if (context.read<CommentController>().peekCommentsCache(postId: postId) !=
        null) {
      await _loadFullCommentsForPost(postId, forceReload: true);
      return;
    }
    await _loadTagCommentsForPost(postId, forceReload: true);
  }

  List<Comment> _initialSheetCommentsForPost(int postId) {
    final commentController = context.read<CommentController>();
    final fullComments = commentController.peekCommentsCache(postId: postId);
    if (fullComments != null && fullComments.isNotEmpty) {
      return fullComments;
    }
    return commentController.peekTagCommentsCache(postId: postId) ??
        const <Comment>[];
  }

  /// full thread 갱신 시 controller cache와 이모지 선택 상태를 같은 기준으로 맞춥니다.
  void _replaceCommentCaches(int postId, List<Comment> comments) {
    context.read<CommentController>().replaceCommentsCache(
      postId: postId,
      comments: comments,
    );

    final currentUserId = _userController?.currentUser?.userId;
    if (currentUserId == null) {
      return;
    }

    final selected = _selectedEmojiFromComments(
      comments: comments,
      currentUserNickname: currentUserId,
    );
    if (selected != null) {
      _selectedEmojisByPostId[postId] = selected;
    }
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
          _userController?.currentUser?.profileImageKey;

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
          _userController?.currentUser?.profileImageKey;

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
          _userController?.currentUser?.profileImageKey;

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

  void _onCommentSaveSuccess(int postId, Comment _) {
    if (!mounted) return;
    setState(() {
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
    context.read<CommentController>().invalidatePostCaches(postId: postId);
    _selectedEmojisByPostId.remove(postId);
    _pendingCommentDrafts.remove(postId);
    _pendingCommentMarkers.remove(postId);
    _resolvedAudioUrls.remove(postId);
    _inFlightTagCommentLoads.remove(postId);
    _inFlightFullCommentLoads.remove(postId);

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
    unawaited(_loadUserProfileImage());
    _loadTagCommentsForPost(_posts[_currentIndex].id);
  }

  Future<void> _stopAudio() async {
    await _audioController.stopRealtimeAudio();
  }

  /// 미디어(사진/비디오) 다운로드 처리
  Future<void> _downloadPhoto() async {
    try {
      final currentPost = _posts[_currentIndex];
      final mediaUrl = await _resolveMediaUrl(currentPost);

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
