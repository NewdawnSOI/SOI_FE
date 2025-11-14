import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/firebase_logic/controllers/comment_record_controller.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../firebase_logic/controllers/auth_controller.dart';
import '../../../firebase_logic/controllers/comment_audio_controller.dart';
import '../../../firebase_logic/controllers/category_controller.dart';
import '../../../firebase_logic/models/photo_data_model.dart';
import '../../../firebase_logic/models/comment_record_model.dart';
import '../../../utils/position_converter.dart';
import '../../about_feed/manager/voice_comment_state_manager.dart';
import '../../about_archiving/screens/archive_detail/category_photos_screen.dart';
import '../about_voice_comment/voice_comment_list_sheet.dart';
import 'first_line_ellipsis_text.dart';
import 'category_label_widget.dart';
import 'audio_control_widget.dart';

/// 사진 표시 위젯
class PhotoDisplayWidget extends StatefulWidget {
  final MediaDataModel photo;
  final String categoryName;
  // Archive 여부에 따라 카테고리 라벨 숨김
  final bool isArchive;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Function(String, Offset) onProfileImageDragged;
  final Function(MediaDataModel) onToggleAudio;
  final Map<String, PendingVoiceComment> pendingVoiceComments;

  const PhotoDisplayWidget({
    super.key,
    required this.photo,
    required this.categoryName,
    this.isArchive = false,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget> {
  // 선택된(롱프레스) 음성 댓글 ID 및 위치
  String? _selectedCommentId;
  Offset? _selectedCommentPosition; // 스택(이미지) 내부 좌표 (아바타 중심)
  bool _showActionOverlay = false; // 선택된 댓글 아래로 마스킹 & 팝업 표시 여부
  // 해당 사진(위젯 인스턴스)에서 음성 댓글 프로필 표시 여부
  bool _isShowingComments = false; // 기본은 숨김
  bool _autoOpenedOnce = false; // 최초 자동 열림 1회 제어
  bool _isCaptionExpanded = false; // caption 확장 여부

  final CommentRecordController _commentRecordController =
      CommentRecordController();

  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.photo.id];
    if (pending == null || pending.relativePosition == null) {
      return null;
    }

    final actualImageSize = Size(354.w.toDouble(), 500.h.toDouble());
    final absolutePosition = PositionConverter.toAbsolutePosition(
      pending.relativePosition!,
      actualImageSize,
    );
    final clampedPosition = PositionConverter.clampPosition(
      absolutePosition,
      actualImageSize,
    );

    final profileImageUrl =
        pending.profileImageUrl ??
        ((pending.recorderUserId != null && pending.recorderUserId!.isNotEmpty)
            ? widget.userProfileImages[pending.recorderUserId!]
            : null);

    return Positioned(
      left: clampedPosition.dx - 13.5,
      top: clampedPosition.dy - 13.5,
      child: IgnorePointer(child: _buildPendingAvatar(profileImageUrl)),
    );
  }

  Widget _buildPendingAvatar(String? imageUrl) {
    final Widget avatarContent;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 27,
          height: 27,
          fit: BoxFit.cover,
          memCacheWidth: (27 * 4).round(),
          maxWidthDiskCache: (27 * 4).round(),
          placeholder: (context, url) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFF2A2A2A),
              highlightColor: const Color(0xFF3A3A3A),
              child: Container(
                width: 27,
                height: 27,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF2A2A2A),
                ),
              ),
            );
          },
          errorWidget: (context, url, error) {
            return Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: const Color(0xffd9d9d9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white),
            );
          },
        ),
      );
    } else {
      avatarContent = Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          color: const Color(0xffd9d9d9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    return Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Opacity(opacity: 0.8, child: avatarContent),
    );
  }

  /// 카테고리 화면으로 이동
  void _navigateToCategory() async {
    final categoryId = widget.photo.categoryId;
    if (categoryId.isEmpty) {
      debugPrint('카테고리 ID가 없습니다');
      return;
    }

    try {
      final categoryController = context.read<CategoryController>();
      final category = await categoryController.getCategory(categoryId);
      if (category == null) {
        debugPrint('카테고리를 찾을 수 없습니다: $categoryId');
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return CategoryPhotosScreen(category: category);
            },
          ),
        );
        debugPrint('카테고리로 이동: $categoryId');
      }
    } catch (e) {
      debugPrint('카테고리 로드 실패: $e');
    }
  }

  /// 사용자 프로필 이미지 위젯 빌드 (Caption에서만 사용)
  Widget _buildUserProfileWidget(BuildContext context) {
    final userId = widget.photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = widget.profileLoadingStates[userId] ?? false;

        if (isLoading) {
          return CircleAvatar(
            radius: 100,
            backgroundColor: Colors.grey[700],
            child: SizedBox(
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        return StreamBuilder<String>(
          stream: authController.getUserProfileImageUrlStream(userId),
          builder: (context, snapshot) {
            final profileImageUrl = snapshot.data ?? '';

            return ClipOval(
              child: profileImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      fit: BoxFit.cover,
                      // 메모리 최적화: 프로필 이미지 크기 제한
                      memCacheWidth: (profileSize * 4).round(),
                      maxWidthDiskCache: (profileSize * 4).round(),
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: const Color(0xFF2A2A2A),
                        highlightColor: const Color(0xFF3A3A3A),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: profileSize,
                        height: profileSize,
                        decoration: BoxDecoration(
                          color: Color(0xffd9d9d9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    )
                  : Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(
                        color: Color(0xffd9d9d9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant PhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 최초로 현재 사용자 댓글이 생긴 시점에 한 번만 자동 표시
    if (!_autoOpenedOnce) {
      try {
        final authController = context.read<AuthController?>();
        final uid = authController?.currentUser?.uid;
        if (uid != null) {
          final comments =
              widget.photoComments[widget.photo.id] ??
              const <CommentRecordModel>[];
          final hasUserComment = comments.any((c) => c.recorderUser == uid);
          if (hasUserComment) {
            setState(() {
              _isShowingComments = true; // 한번 자동으로 켜기
              _autoOpenedOnce = true; // 재자동 방지
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 이미지 영역에만 DragTarget 적용 - Builder Pattern 사용
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Builder(
            builder: (builderContext) {
              return DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  return (details.data).isNotEmpty;
                },
                onAcceptWithDetails: (details) {
                  // 드롭된 좌표를 사진 내 상대 좌표로 변환
                  final RenderBox renderBox =
                      builderContext.findRenderObject() as RenderBox;
                  final localPosition = renderBox.globalToLocal(details.offset);

                  // 프로필 크기(64)의 반지름만큼 보정하여 중심점으로 조정
                  final adjustedPosition = Offset(
                    localPosition.dx + 32,
                    localPosition.dy + 32,
                  );

                  widget.onProfileImageDragged(
                    widget.photo.id,
                    adjustedPosition,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 메모리 최적화: 배경 이미지 크기 제한
                      GestureDetector(
                        onTap: () {
                          // 음성 댓글이 있을 때만 토글 동작
                          final hasComments =
                              (widget.photoComments[widget.photo.id] ?? [])
                                  .isNotEmpty;
                          if (hasComments) {
                            setState(() {
                              _isShowingComments = !_isShowingComments;
                            });
                          }
                        },
                        child: CachedNetworkImage(
                          imageUrl: widget.photo.imageUrl,
                          fit: BoxFit.cover,
                          width: 354.w,
                          height: 500.h,

                          // 메모리 최적화: 디코딩 크기 제한으로 메모리 사용량 대폭 감소
                          memCacheWidth: (354 * 2).round(),
                          maxWidthDiskCache: (354 * 2).round(),

                          placeholder: (context, url) {
                            return Container(
                              width: 354.w,
                              height: 500.h,
                              color: Colors.grey[900],
                              child: const Center(),
                            );
                          },
                        ),
                      ),
                      // 댓글 보기 토글 시(롱프레스 액션 오버레이 아닐 때) 살짝 어둡게 마스킹하여 아바타 대비 확보
                      if (_isShowingComments && !_showActionOverlay)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      // 선택된 댓글이 있을 때 전체 마스킹 (선택된 것만 위에 남김)
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showActionOverlay = false;
                                _selectedCommentId = null;
                                _selectedCommentPosition = null;
                              });
                            },
                            child: Container(
                              color: Color(0xffd9d9d9).withValues(alpha: 0.45),
                            ),
                          ),
                        ),

                      // 카테고리 정보
                      if (!widget.isArchive)
                        CategoryLabelWidget(
                          categoryName: widget.categoryName,
                          onTap: _navigateToCategory,
                        ),

                      // 오디오 컨트롤 오버레이
                      if (widget.photo.audioUrl.isNotEmpty)
                        Positioned(
                          left: 20.w,
                          bottom: 7.h,
                          child: AudioControlWidget(
                            photo: widget.photo,
                            onAudioTap: () =>
                                widget.onToggleAudio(widget.photo),
                            hasComments:
                                (widget.photoComments[widget.photo.id] ?? [])
                                    .isNotEmpty,
                            onCommentIconTap: () {
                              setState(() {
                                _isShowingComments = !_isShowingComments;
                              });
                            },
                          ),
                        ),

                      // Caption 표시 (오디오가 없을 때)
                      if (widget.photo.audioUrl.isEmpty &&
                          widget.photo.caption != null &&
                          widget.photo.caption!.isNotEmpty)
                        Positioned(
                          left: 20.w,
                          bottom: 7.h,
                          child: Row(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // 텍스트가 오버플로우되는지 확인
                                  final captionStyle = TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w400,
                                  );
                                  final textSpan = TextSpan(
                                    text: widget.photo.caption!,
                                    style: captionStyle,
                                  );

                                  final textPainter = TextPainter(
                                    text: textSpan,
                                    maxLines: 1,
                                    textDirection: TextDirection.ltr,
                                  );

                                  textPainter.layout(
                                    maxWidth: 278.w - 10.w * 2 - 27 - 12.w,
                                  );
                                  final isOverflowing =
                                      textPainter.didExceedMaxLines ||
                                      widget.photo.caption!.contains('\n');

                                  return GestureDetector(
                                    onTap: isOverflowing
                                        ? () {
                                            setState(() {
                                              _isCaptionExpanded =
                                                  !_isCaptionExpanded;
                                            });
                                          }
                                        : null,
                                    child: Container(
                                      width: 278.w,
                                      constraints: BoxConstraints(
                                        minHeight: 40.h,
                                        maxHeight: _isCaptionExpanded
                                            ? 274.h
                                            : 40.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xff000000,
                                        ).withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: _isCaptionExpanded
                                              ? CrossAxisAlignment.start
                                              : CrossAxisAlignment.center,
                                          children: [
                                            // 왼쪽 프로필 이미지
                                            Container(
                                              width: 27,
                                              height: 27,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child: _buildUserProfileWidget(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12.w),

                                            // Caption 텍스트 with Scroll and Fade Effect
                                            Expanded(
                                              child: _isCaptionExpanded
                                                  ? ShaderMask(
                                                      shaderCallback:
                                                          (Rect bounds) {
                                                            return LinearGradient(
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: [
                                                                Colors
                                                                    .transparent,
                                                                Colors.white,
                                                                Colors.white,
                                                                Colors
                                                                    .transparent,
                                                              ],
                                                              stops: [
                                                                0.0,
                                                                0.05,
                                                                0.95,
                                                                1.0,
                                                              ],
                                                            ).createShader(
                                                              bounds,
                                                            );
                                                          },
                                                      blendMode:
                                                          BlendMode.dstIn,
                                                      child: SingleChildScrollView(
                                                        physics:
                                                            BouncingScrollPhysics(),
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                vertical: 6.h,
                                                              ),
                                                          child: Text(
                                                            widget
                                                                .photo
                                                                .caption!,
                                                            style: captionStyle
                                                                .copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : FirstLineEllipsisText(
                                                      text:
                                                          widget.photo.caption!,
                                                      style: captionStyle
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // 댓글 아이콘 영역
                              SizedBox(
                                width: 60.w,
                                child:
                                    (widget.photoComments[widget.photo.id] ??
                                            [])
                                        .isNotEmpty
                                    ? Center(
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isShowingComments =
                                                  !_isShowingComments;
                                            });
                                          },
                                          icon: Image.asset(
                                            "assets/comment_profile_icon.png",
                                            width: 25.w,
                                            height: 25.h,
                                          ),
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                        ),

                      // 모든 댓글의 드롭된 프로필 이미지들 표시 (상대 좌표 사용)
                      ...(() {
                        // 숨김 상태에서는 아무 것도 렌더링하지 않음
                        if (!_isShowingComments) {
                          return <Widget>[];
                        }
                        final comments =
                            widget.photoComments[widget.photo.id] ?? [];

                        final commentsWithPosition = comments
                            .where(
                              (comment) => comment.relativePosition != null,
                            )
                            .toList();

                        return commentsWithPosition.map((comment) {
                          // 오버레이 중이면 선택된 댓글 외에는 숨김
                          if (_showActionOverlay &&
                              _selectedCommentId != null &&
                              comment.id != _selectedCommentId) {
                            return const SizedBox.shrink();
                          }
                          // 상대 좌표를 절대 좌표로 변환 (실제 렌더링 크기 사용)
                          final actualImageSize = Size(
                            354.w.toDouble(),
                            500.h.toDouble(),
                          );
                          Offset absolutePosition;

                          if (comment.relativePosition != null) {
                            // 새로운 상대 좌표 사용
                            absolutePosition =
                                PositionConverter.toAbsolutePosition(
                                  comment.relativePosition!,
                                  actualImageSize,
                                );
                          } else {
                            return Container(); // 위치 정보가 없으면 빈 컨테이너
                          }

                          // 프로필 이미지가 화면을 벗어나지 않도록 위치 조정
                          final clampedPosition =
                              PositionConverter.clampPosition(
                                absolutePosition,
                                actualImageSize,
                              );

                          return Positioned(
                            left: clampedPosition.dx - 13.5,
                            top: clampedPosition.dy - 13.5,
                            child: GestureDetector(
                              onLongPress: () {
                                // 롱프레스 시 선택 & 마스킹 + 액션 팝업 노출
                                setState(() {
                                  _selectedCommentId = comment.id;
                                  _selectedCommentPosition = clampedPosition;
                                  _showActionOverlay = true;
                                });
                              },
                              child: Consumer2<AuthController, CommentAudioController>(
                                builder:
                                    (
                                      context,
                                      authController,
                                      commentAudioController,
                                      child,
                                    ) {
                                      // 현재 댓글이 재생 중인지 확인
                                      final isCurrentCommentPlaying =
                                          commentAudioController
                                              .isCommentPlaying(comment.id);
                                      final isSelected =
                                          _showActionOverlay &&
                                          _selectedCommentId == comment.id;

                                      return InkWell(
                                        onTap: () async {
                                          if (!mounted) {
                                            return;
                                          }

                                          try {
                                            final recordController = context
                                                .read<
                                                  CommentRecordController
                                                >();

                                            await showModalBottomSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (sheetContext) {
                                                return ChangeNotifierProvider.value(
                                                  value: recordController,
                                                  child: SizedBox(
                                                    height: 480.h,
                                                    child:
                                                        VoiceCommentListSheet(
                                                          photoId:
                                                              widget.photo.id,
                                                          categoryId: widget
                                                              .photo
                                                              .categoryId,
                                                          selectedCommentId:
                                                              comment.id,
                                                        ),
                                                  ),
                                                );
                                              },
                                            );
                                          } catch (e) {
                                            debugPrint(
                                              'Feed - 댓글 팝업 표시 실패: $e',
                                            );
                                          }
                                        },
                                        child: Container(
                                          width: 27,
                                          height: 27,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.45,
                                                          ),
                                                      blurRadius: 6,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : null,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.white
                                                  : isCurrentCommentPlaying
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              width: isSelected ? 2.2 : 1,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              ClipOval(
                                                child:
                                                    comment
                                                        .profileImageUrl
                                                        .isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: comment
                                                            .profileImageUrl,
                                                        width: 27,
                                                        height: 27,
                                                        fit: BoxFit.cover,
                                                        memCacheWidth: (27 * 4)
                                                            .round(),
                                                        maxWidthDiskCache:
                                                            (27 * 4).round(),
                                                        placeholder:
                                                            (
                                                              context,
                                                              url,
                                                            ) => Shimmer.fromColors(
                                                              baseColor:
                                                                  const Color(
                                                                    0xFF2A2A2A,
                                                                  ),
                                                              highlightColor:
                                                                  const Color(
                                                                    0xFF3A3A3A,
                                                                  ),
                                                              child: Container(
                                                                decoration: const BoxDecoration(
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color: Color(
                                                                    0xFF2A2A2A,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        errorWidget:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => Container(
                                                              width: 27,
                                                              height: 27,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: Color(
                                                                      0xffd9d9d9,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                              child: Icon(
                                                                Icons.person,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                      )
                                                    : Container(
                                                        width: 27,
                                                        height: 27,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Color(
                                                                0xffd9d9d9,
                                                              ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: Icon(
                                                          Icons.person,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                              ),
                            ),
                          );
                        });
                      })(),
                      ...(() {
                        if (!_isShowingComments) {
                          return <Widget>[];
                        }
                        final pendingMarker = _buildPendingMarker();
                        if (pendingMarker == null) {
                          return <Widget>[];
                        }
                        return <Widget>[pendingMarker];
                      })(),
                      // 선택된 댓글에 대한 작은 액션 팝업 (삭제 등) - 이미지 영역 안에 직접 렌더
                      if (_showActionOverlay &&
                          _selectedCommentId != null &&
                          _selectedCommentPosition != null)
                        Builder(
                          builder: (context) {
                            final imageWidth = 354.w.toDouble();
                            final popupWidth = 180.0;

                            // 기본 위치: 선택된 아바타 오른쪽 살짝 아래
                            double left = _selectedCommentPosition!.dx;
                            double top = _selectedCommentPosition!.dy + 20;
                            // 화면 밖으로 나가지 않도록 클램프
                            if (left + popupWidth > imageWidth) {
                              left = imageWidth - popupWidth - 8;
                            }

                            return Positioned(
                              left: left,
                              top: top,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: 173.w,
                                  height: 45.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1C),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      if (_selectedCommentId == null) return;
                                      final targetId = _selectedCommentId!;
                                      try {
                                        await _commentRecordController
                                            .hardDeleteCommentRecord(
                                              targetId,
                                              widget.photo.id,
                                            );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('댓글 삭제 실패: $e'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            // 오버레이 및 선택 해제 + 기본 화면 복귀 위해 댓글 표시도 종료
                                            _showActionOverlay = false;
                                            _selectedCommentId = null;
                                            _selectedCommentPosition = null;
                                            _isShowingComments = false; // 배경 원복
                                          });
                                        }
                                      }
                                    },
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 13.96.w),
                                        Image.asset(
                                          "assets/trash_red.png",
                                          width: 11.2.w,
                                          height: 12.6.h,
                                        ),
                                        SizedBox(width: 12.59.w),
                                        Text(
                                          '댓글 삭제',
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xffff0000),
                                            fontFamily: 'Pretendard',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
