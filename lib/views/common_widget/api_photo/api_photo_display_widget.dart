import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/comment_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import '../about_comment/api_voice_comment_list_sheet.dart';
import '../about_comment/pending_api_voice_comment.dart';
import 'api_audio_control_widget.dart';
import 'services/api_photo_tag_geometry_service.dart';
import 'services/api_photo_waveform_parser_service.dart';
import 'tag_pointer.dart';
import 'widgets/api_photo_caption_overlay.dart';
import 'widgets/api_photo_comment_overlay.dart';
import 'widgets/api_photo_delete_action_popup.dart';
import 'widgets/api_photo_media_content.dart';

Widget _heroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = (toHeroContext.widget as Hero).child;
  final fromHero = (fromHeroContext.widget as Hero).child;
  final shuttleChild = flightDirection == HeroFlightDirection.push
      ? toHero
      : fromHero;
  return Material(
    type: MaterialType.transparency,
    child: ClipRect(child: shuttleChild),
  );
}

class ExpandedMediaTagOverlayData {
  final String tagKey;
  final Comment comment;
  final Offset globalCircleCenter;
  final double collapsedContentSize;
  final double expandedContentSize;
  final VoidCallback onDismiss;
  final VoidCallback? onLongPress;

  const ExpandedMediaTagOverlayData({
    required this.tagKey,
    required this.comment,
    required this.globalCircleCenter,
    required this.collapsedContentSize,
    required this.expandedContentSize,
    required this.onDismiss,
    this.onLongPress,
  });
}

class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
  final int categoryId;
  final String categoryName;
  final bool isArchive;
  final bool isFromCamera;
  final Map<int, List<Comment>> postComments;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;
  final Future<void> Function(int postId)? onCommentsReloadRequested;
  final ValueChanged<ExpandedMediaTagOverlayData?>?
  onExpandedMediaOverlayChanged;

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    this.isFromCamera = false,
    required this.postComments,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
    this.onCommentsReloadRequested,
    this.onExpandedMediaOverlayChanged,
  });

  @override
  State<ApiPhotoDisplayWidget> createState() => _ApiPhotoDisplayWidgetState();
}

class _ApiPhotoDisplayWidgetState extends State<ApiPhotoDisplayWidget>
    with WidgetsBindingObserver {
  static const double _avatarSize = 27.0;
  static const double _expandedAvatarSize = 108.0;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  Size get _imageSize => Size(_imageWidth.w, _imageHeight.h);

  String get _heroTag => 'archive_photo_${widget.categoryId}_${widget.post.id}';

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  String? _selectedCommentKey;
  String? _expandedMediaTagKey;
  int? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;
  String? _uploaderProfileImageUrl;
  bool _isProfileLoading = false;
  final GlobalKey _displayStackKey = GlobalKey();

  List<Comment> get _postComments =>
      widget.postComments[widget.post.id] ?? const <Comment>[];

  bool get _hasPendingMarker =>
      widget.pendingVoiceComments[widget.post.id] != null;

  bool get _hasComments => _postComments.isNotEmpty;

  bool get _hasCaption => widget.post.content?.isNotEmpty ?? false;

  bool get _isTextOnlyPost {
    final hasText = widget.post.content?.trim().isNotEmpty ?? false;
    return widget.post.postType == PostType.textOnly ||
        (!widget.post.hasMedia && hasText);
  }

  String? postImageUrl;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;
  bool _isVideoCoverMode = false;
  bool _isImageCoverMode = false;
  bool _isVideoVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isImageCoverMode = widget.isFromCamera;
    _isVideoCoverMode = widget.isFromCamera;
    _isShowingComments = _hasComments || _hasPendingMarker;
    _scheduleProfileLoad(widget.post.userProfileImageKey);

    final url = widget.post.postFileUrl;
    postImageUrl = (url != null && url.isNotEmpty) ? url : null;
    _ensureVideoController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.post.isVideo) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseVideo();
    }
  }

  @override
  void deactivate() {
    if (widget.post.isVideo) {
      _pauseVideo();
    }
    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant ApiPhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isFromCamera != widget.isFromCamera) {
      setState(() {
        _isImageCoverMode = widget.isFromCamera;
        _isVideoCoverMode = widget.isFromCamera;
      });
    }

    if (_hasComments && !_autoOpenedOnce) {
      setState(() {
        _isShowingComments = true;
        _autoOpenedOnce = true;
      });
    }

    if (_hasPendingMarker && !_isShowingComments) {
      setState(() {
        _isShowingComments = true;
      });
    }

    if (oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl ||
        oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      _scheduleProfileLoad(widget.post.userProfileImageKey);
    }

    if (oldWidget.post.postFileUrl != widget.post.postFileUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _safeSetState(() {
        final url = widget.post.postFileUrl;
        postImageUrl = (url != null && url.isNotEmpty) ? url : null;
      });
      _ensureVideoController(forceRecreate: true);
    } else {
      _ensureVideoController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearExpandedMediaOverlay();
    _disposeVideoController();
    super.dispose();
  }

  void _ensureVideoController({bool forceRecreate = false}) {
    if (!widget.post.isVideo) {
      _disposeVideoController();
      return;
    }

    final url = postImageUrl;
    if (url == null || url.isEmpty) return;

    final currentUrl = _videoController?.dataSource;
    if (!forceRecreate && _videoController != null && currentUrl == url) {
      return;
    }

    _disposeVideoController();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;
    _videoInitialization = controller.initialize().then((_) async {
      await controller.setLooping(true);
      if (_isVideoVisible) {
        await controller.play();
      }
      _safeSetState(() {});
    });
  }

  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  void _pauseVideo() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _playVideoIfReady() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (!controller.value.isPlaying) {
      controller.play();
    }
  }

  void _loadProfileImage(String? key) {
    final url = widget.post.userProfileImageUrl;
    _safeSetState(() {
      _uploaderProfileImageUrl = (url != null && url.isNotEmpty) ? url : null;
      _isProfileLoading = false;
    });
  }

  void _scheduleProfileLoad(String? key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfileImage(key);
      }
    });
  }

  void _handleVideoVisibilityChanged(bool visible) {
    if (_isVideoVisible == visible) return;
    _isVideoVisible = visible;
    if (visible) {
      _playVideoIfReady();
    } else {
      _pauseVideo();
    }
  }

  void _notifyExpandedMediaOverlay(ExpandedMediaTagOverlayData? data) {
    widget.onExpandedMediaOverlayChanged?.call(data);
  }

  void _clearExpandedMediaOverlay() {
    _notifyExpandedMediaOverlay(null);
  }

  void _emitExpandedMediaOverlay({
    required String tagKey,
    required Comment comment,
    required Offset localCircleCenter,
    required double collapsedContentSize,
    required double expandedContentSize,
    VoidCallback? onLongPress,
  }) {
    final callback = widget.onExpandedMediaOverlayChanged;
    if (callback == null) return;

    final renderBox = _displayStackKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return;

    final globalCircleCenter = renderBox.localToGlobal(localCircleCenter);
    callback(
      ExpandedMediaTagOverlayData(
        tagKey: tagKey,
        comment: comment,
        globalCircleCenter: globalCircleCenter,
        collapsedContentSize: collapsedContentSize,
        expandedContentSize: expandedContentSize,
        onDismiss: _collapseExpandedMediaTag,
        onLongPress: onLongPress,
      ),
    );
  }

  void _collapseExpandedMediaTag() {
    if (!mounted) return;
    if (_expandedMediaTagKey == null) {
      _clearExpandedMediaOverlay();
      return;
    }
    setState(() {
      _expandedMediaTagKey = null;
    });
    _clearExpandedMediaOverlay();
  }

  void _showExpandedMediaOverlay({
    required String tagKey,
    required Comment comment,
    required Offset tipAnchor,
    VoidCallback? onLongPress,
  }) {
    final localCircleCenter =
        ApiPhotoTagGeometryService.tagCircleCenterFromTipAnchor(
          tipAnchor,
          _avatarSize,
        );

    _emitExpandedMediaOverlay(
      tagKey: tagKey,
      comment: comment,
      localCircleCenter: localCircleCenter,
      collapsedContentSize: _avatarSize,
      expandedContentSize: _expandedAvatarSize,
      onLongPress: onLongPress,
    );
  }

  void _handleCommentTap({
    required Comment comment,
    required String key,
    required Offset tipAnchor,
  }) {
    if (comment.type == CommentType.photo) {
      if (!ApiPhotoTagGeometryService.canExpandMediaComment(comment)) {
        _openCommentSheet(key);
        return;
      }

      if (widget.onExpandedMediaOverlayChanged == null) {
        _openCommentSheet(key);
        return;
      }

      if (_expandedMediaTagKey == key) {
        _collapseExpandedMediaTag();
        return;
      }

      setState(() {
        _expandedMediaTagKey = key;
      });
      _showExpandedMediaOverlay(
        tagKey: key,
        comment: comment,
        tipAnchor: tipAnchor,
        onLongPress: () => _handleCommentLongPress(
          key: key,
          commentId: comment.id,
          position: tipAnchor,
        ),
      );
      return;
    }

    if (_expandedMediaTagKey != null) {
      _collapseExpandedMediaTag();
    }
    _openCommentSheet(key);
  }

  void _handleBaseTap() {
    if (_showActionOverlay) {
      _dismissOverlay();
      return;
    }
    if (_expandedMediaTagKey != null) {
      _collapseExpandedMediaTag();
      return;
    }
    if (_hasComments || _hasPendingMarker) {
      setState(() {
        _isShowingComments = !_isShowingComments;
        if (!_isShowingComments) {
          _expandedMediaTagKey = null;
        }
      });
      if (!_isShowingComments) {
        _clearExpandedMediaOverlay();
      }
    }
  }

  void _dismissOverlay() {
    setState(() {
      _showActionOverlay = false;
      _selectedCommentKey = null;
      _expandedMediaTagKey = null;
      _selectedCommentId = null;
      _selectedCommentPosition = null;
    });
    _clearExpandedMediaOverlay();
  }

  void _openCommentSheet(String selectedKey) {
    final comments = _postComments;
    if (_expandedMediaTagKey != null) {
      setState(() {
        _expandedMediaTagKey = null;
      });
      _clearExpandedMediaOverlay();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => AudioController(),
          child: ApiVoiceCommentListSheet(
            postId: widget.post.id,
            comments: comments,
            selectedCommentId: selectedKey,
            onCommentsUpdated: (updatedComments) {
              if (!mounted) return;
              setState(() {
                widget.postComments[widget.post.id] = updatedComments;
              });
            },
          ),
        );
      },
    );
  }

  void _handleCommentLongPress({
    required String key,
    required int? commentId,
    required Offset position,
  }) {
    if (commentId == null) {
      _showSnackBar(tr('comments.delete_unavailable', context: context));
      return;
    }
    setState(() {
      _selectedCommentKey = key;
      _expandedMediaTagKey = null;
      _selectedCommentId = commentId;
      _selectedCommentPosition = position;
      _showActionOverlay = true;
    });
    _clearExpandedMediaOverlay();
  }

  Future<void> _deleteSelectedComment() async {
    final targetId = _selectedCommentId;
    if (targetId == null) return;
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final success = await commentController.deleteComment(targetId);
      if (!mounted) return;
      if (success) {
        _removeCommentFromCache(targetId);
        await widget.onCommentsReloadRequested?.call(widget.post.id);
        if (!mounted) return;
        _showSnackBar(tr('comments.delete_success', context: context));
        _dismissOverlay();
      } else {
        _showSnackBar(tr('comments.delete_failed', context: context));
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(tr('comments.delete_error', context: context));
    }
  }

  void _removeCommentFromCache(int commentId) {
    final updated = List<Comment>.from(
      widget.postComments[widget.post.id] ?? const <Comment>[],
    )..removeWhere((comment) => comment.id == commentId);
    widget.postComments[widget.post.id] = updated;
    setState(() {});
  }

  void _navigateToCategory() {
    final controller = context.read<api_category.CategoryController?>();
    final category = controller?.getCategoryById(widget.categoryId);
    if (category == null) {
      _showSnackBar('카테고리 정보를 불러오지 못했습니다.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiCategoryPhotosScreen(category: category),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryTrimmed = widget.categoryName.trim();
    final isEnglishCategory =
        categoryTrimmed.isNotEmpty &&
        RegExp(r'^[A-Za-z\s]+$').hasMatch(categoryTrimmed);
    final waveformData = ApiPhotoWaveformParserService.parse(
      widget.post.waveformData,
    );
    final deletePopup =
        _showActionOverlay &&
            _selectedCommentPosition != null &&
            _selectedCommentId != null
        ? ApiPhotoDeleteActionPopup(
            position: _selectedCommentPosition!,
            imageWidth: _imageSize.width,
            onDeleteTap: _deleteSelectedComment,
          )
        : null;
    final showCaptionOverlay = _hasCaption && !_isTextOnlyPost;

    return Center(
      child: SizedBox(
        width: _imageSize.width,
        height: _imageSize.height,
        child: Builder(
          builder: (builderContext) {
            final mediaBase = ApiPhotoMediaContent(
              isTextOnlyPost: _isTextOnlyPost,
              isVideoPost: widget.post.isVideo,
              hasImage: widget.post.hasImage,
              mediaUrl: postImageUrl,
              postFileKey: widget.post.postFileKey,
              textContent: widget.post.content ?? '',
              imageSize: _imageSize,
              videoController: _videoController,
              videoInitialization: _videoInitialization,
              isVideoCoverMode: _isVideoCoverMode,
              isImageCoverMode: _isImageCoverMode,
              onVideoToggleFit: () {
                if (!mounted) return;
                setState(() {
                  _isVideoCoverMode = !_isVideoCoverMode;
                });
              },
              onImageToggleFit: () {
                if (!mounted) return;
                setState(() {
                  _isImageCoverMode = !_isImageCoverMode;
                });
              },
              onVideoVisibilityChanged: _handleVideoVisibilityChanged,
            );

            final mediaFrame = _isTextOnlyPost
                ? mediaBase
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: mediaBase,
                  );

            final mediaWithHero = widget.isArchive
                ? Hero(
                    tag: _heroTag,
                    createRectTween: (begin, end) =>
                        MaterialRectArcTween(begin: begin, end: end),
                    transitionOnUserGestures: true,
                    flightShuttleBuilder: _heroFlightShuttleBuilder,
                    child: mediaFrame,
                  )
                : mediaFrame;

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
              onAcceptWithDetails: (details) {
                final renderBox =
                    builderContext.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.offset);
                final tipOffset = TagBubble.pointerTipOffset(
                  contentSize: _avatarSize,
                );
                widget.onProfileImageDragged(
                  widget.post.id,
                  localPosition + tipOffset,
                );
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: _handleBaseTap,
                  child: Stack(
                    key: _displayStackKey,
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      mediaWithHero,
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _dismissOverlay,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      if (!widget.isArchive)
                        Positioned(
                          top: 11.h,
                          child: GestureDetector(
                            onTap: _navigateToCategory,
                            child: IntrinsicWidth(
                              child: Container(
                                height: 25,
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: isEnglishCategory ? 0 : 2,
                                  bottom: isEnglishCategory ? 2 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.categoryName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Pretendard Variable',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.post.hasAudio)
                        Positioned(
                          left: 18.w,
                          right: 18.w,
                          bottom: 22.h,
                          child: ApiAudioControlWidget(
                            post: widget.post,
                            waveformData: waveformData,
                          ),
                        ),
                      if (!widget.post.hasAudio && showCaptionOverlay)
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ApiPhotoCaptionOverlay(
                                  content: widget.post.content!,
                                  isExpanded: _isCaptionExpanded,
                                  isProfileLoading: _isProfileLoading,
                                  profileImageUrl: _uploaderProfileImageUrl,
                                  profileImageCacheKey:
                                      widget.post.userProfileImageKey,
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _isCaptionExpanded = !_isCaptionExpanded;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      Positioned.fill(
                        child: ApiPhotoCommentOverlay(
                          comments: _postComments,
                          pendingMarker:
                              widget.pendingVoiceComments[widget.post.id],
                          isShowingComments: _isShowingComments,
                          showActionOverlay: _showActionOverlay,
                          selectedCommentKey: _selectedCommentKey,
                          expandedMediaTagKey: _expandedMediaTagKey,
                          imageSize: _imageSize,
                          avatarSize: _avatarSize,
                          onCommentTap: _handleCommentTap,
                          onCommentLongPress: _handleCommentLongPress,
                        ),
                      ),
                      if (deletePopup != null) deletePopup,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
