import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/models/category.dart' as api_category;
import '../../../../api/models/friend.dart';
import '../../screens/archive_detail/api_category_photos_screen.dart';
import '../../screens/archive_detail/widgets/category_photos_header+body/api_category_header_image_prefetch.dart';
import 'api_archive_profile_row_widget.dart';
import 'archive_card_models.dart';
import 'archive_card_placeholders.dart';

import 'package:flutter/foundation.dart' show kDebugMode;

/// 카테고리 카드를 표시하는 위젯
///
/// Parameters:
/// - [category]: 표시할 카테고리 데이터
/// - [isEditMode]: 편집 모드 여부
/// - [isEditing]: 현재 편집 중인지 여부
/// - [editingController]: 편집 중인 텍스트 컨트롤러
/// - [onStartEdit]: 편집 시작 콜백
///
/// Returns:
/// - [Widget]: 카테고리 카드 위젯
class ApiArchiveCardWidget extends StatelessWidget {
  static const Duration _kForwardTransitionDuration = Duration(
    milliseconds: 260,
  );
  static const Duration _kReverseTransitionDuration = Duration(
    milliseconds: 220,
  );
  static const Color _kEmptyCategoryBackgroundColor = Color(0xFF1C1C1C);
  static const Color _kListEmptyCategoryBackgroundColor = Color(0xFF5A5A5A);
  static final Color _kCategoryCardBorderColor = const Color(
    0xFF1C1C1C,
  ).withValues(alpha: 0.5); // 테두리 색상 (투명도 50%)
  static const double _kGridCardBorderRadius = 10.7;
  static const double _kListCardBorderRadius = 9.3;

  final api_category.Category category;
  final bool isListView;
  final bool isEditMode;
  final bool isEditing;
  final TextEditingController? editingController;
  final VoidCallback? onStartEdit;

  const ApiArchiveCardWidget({
    super.key,
    required this.category,
    this.isListView = false,
    this.isEditMode = false,
    this.isEditing = false,
    this.editingController,
    this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<CategoryController, ArchiveCardViewData>(
      selector: (_, controller) {
        final latest = controller.getCategoryById(category.id) ?? category;
        return ArchiveCardViewData.fromCategory(latest);
      },
      builder: (context, cardData, _) {
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        return isListView
            ? _buildListLayout(context, cardData, devicePixelRatio)
            : _buildGridLayout(context, cardData, devicePixelRatio);
      },
    );
  }

  /// 이미지의 URL 주소에서 불필요한 부분(쿼리 파라미터와 프래그먼트)을 제거하는 함수입니다.
  ///
  /// 예를 들어 'https://example.com/image.jpg?size=large#section' 같은 URL에서
  /// '?size=large'와 '#section' 부분을 없애서 'https://example.com/image.jpg'으로 만듭니다.
  ///
  /// 이렇게 정리된 URL을 이미지 캐시의 키(식별자)로 사용하여 같은 이미지를
  /// 효율적으로 저장하고 불러올 수 있습니다.
  /// 이미지 URL에서 쿼리 파라미터와 프래그먼트를 제거하여 캐시 키로 사용하기 위한 정규화 함수
  String _normalizeImageUrlForCache(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri?.replace(query: '', fragment: '').toString() ?? rawUrl;
  }

  String _buildCategoryImageCacheKey(int categoryId, String photoUrl) {
    final normalizedUrl = _normalizeImageUrlForCache(photoUrl);
    return 'archive_category_image_${categoryId}_$normalizedUrl';
  }

  /// 카테고리 사진 화면으로 이동하는 라우트 빌드 함수
  Route<void> _buildCategoryPhotosRoute({
    required BuildContext context,
    required api_category.Category category,
    required CategoryHeaderImagePrefetch? prefetchedHeaderImage,
  }) {
    final platform = Theme.of(context).platform;
    final useGestureBackRoute =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    if (useGestureBackRoute) {
      return MaterialPageRoute<void>(
        builder: (_) => ApiCategoryPhotosScreen(
          category: category,
          prefetchedHeaderImage: prefetchedHeaderImage,
        ),
      );
    }

    // 커스텀 페이드 트랜지션 라우트
    // iOS/macOS에서는 기본적으로 제스처 백이 지원되는 MaterialPageRoute를 사용하고,
    // 그 외 플랫폼에서는 커스텀 페이드 트랜지션을 적용한 PageRouteBuilder를 사용합니다.
    return PageRouteBuilder<void>(
      transitionDuration: _kForwardTransitionDuration,
      reverseTransitionDuration: _kReverseTransitionDuration,
      pageBuilder: (_, animation, __) => ApiCategoryPhotosScreen(
        category: category,
        prefetchedHeaderImage: prefetchedHeaderImage,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  void _handleTap(BuildContext context) {
    final latestCategory =
        context.read<CategoryController>().getCategoryById(category.id) ??
        category;
    final headerImagePrefetch = CategoryHeaderImagePrefetch.fromCategory(
      latestCategory,
    );
    if (headerImagePrefetch != null) {
      _prefetchCategoryHeaderImage(context, headerImagePrefetch);
    }

    final postController = context.read<PostController>();
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();
    final currentUser = userController.currentUser;

    if (currentUser != null) {
      _prefetchCategoryData(
        postController: postController,
        friendController: friendController,
        categoryId: latestCategory.id,
        userId: currentUser.id,
      );
    }

    Navigator.push(
      context,
      _buildCategoryPhotosRoute(
        context: context,
        category: latestCategory,
        prefetchedHeaderImage: headerImagePrefetch,
      ),
    );
  }

  Widget _buildGridLayout(
    BuildContext context,
    ArchiveCardViewData cardData,
    double devicePixelRatio,
  ) {
    return InkWell(
      onTap: isEditMode ? null : () => _handleTap(context),
      child: Stack(
        children: [
          // 카테고리 이미지 (전체 채우기)
          _buildCategoryImage(
            width: 170.sp,
            height: 204.sp,
            borderRadius: _kGridCardBorderRadius,
            photoUrl: cardData.photoUrl,
            devicePixelRatio: devicePixelRatio,
          ),

          // 고정 배지
          // TODO: 위치 조정 필요
          //_buildPinnedBadge(top: 5.sp, left: 5.sp),

          // 신규 배지
          _buildNewBadge(top: 16.sp, left: (140.39).sp, isNew: cardData.isNew),

          // 카테고리 제목: 왼쪽 위
          Padding(
            padding: EdgeInsets.only(left: 15.sp, top: 15.sp),
            child: _buildTitleWidget(
              context,
              fontSize: 16.sp,
              name: cardData.name,
            ),
          ),

          // 프로필 Row: 오른쪽 아래
          Padding(
            padding: EdgeInsets.only(right: (8.39).sp, bottom: 9.sp),
            child: Align(
              alignment: Alignment.bottomRight,
              child: _buildProfileRow(
                profileRowData: cardData.profileRowData,
                isListStyle: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListLayout(
    BuildContext context,
    ArchiveCardViewData cardData,
    double devicePixelRatio,
  ) {
    return InkWell(
      onTap: isEditMode ? null : () => _handleTap(context),
      borderRadius: BorderRadius.circular(_kListCardBorderRadius),
      child: SizedBox(
        height: 90.h,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = constraints.maxWidth * 0.408;
            final cardHeight = constraints.maxHeight;
            final listBorderRadius = BorderRadius.circular(
              _kListCardBorderRadius,
            );

            return Container(
              decoration: BoxDecoration(
                color: _kEmptyCategoryBackgroundColor,
                borderRadius: listBorderRadius,
                border: Border.all(color: _kCategoryCardBorderColor, width: 1),
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      // 카테고리 이미지 (왼쪽 절반)
                      _buildCategoryImageSurface(
                        width: imageWidth,
                        height: cardHeight,
                        borderRadius: BorderRadius.all(
                          Radius.circular(_kListCardBorderRadius),
                        ),
                        photoUrl: cardData.photoUrl,
                        devicePixelRatio: devicePixelRatio,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: (14.4).sp,
                            right: 13.sp,
                            top: 9.sp,
                            bottom: 5.sp,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildTitleWidget(
                                      context,
                                      fontSize: 14.sp,
                                      name: cardData.name,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Pretendard Variable',
                                      maxLines: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  _buildNewBadgeContent(
                                    size: 15.sp,
                                    isNew: cardData.isNew,
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: _buildProfileRow(
                                  profileRowData: cardData.profileRowData,
                                  isListStyle: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 카테고리 제목 위젯 빌드
  Widget _buildTitleWidget(
    BuildContext context, {
    required double fontSize,
    required String name,
    FontWeight fontWeight = FontWeight.bold,
    String fontFamily = 'Pretendard',
    int maxLines = 1,
  }) {
    if (isEditing && editingController != null) {
      return TextField(
        controller: editingController,
        style: TextStyle(
          color: const Color(0xFFF8F8F8),
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: fontFamily,
        ),
        cursorColor: const Color(0xfff9f9f9),
        decoration: const InputDecoration(
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        maxLines: 1,
        autofocus: true,
      );
    }

    return Text(
      name,
      style: TextStyle(
        color: const Color(0xFFF9F9F9),
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        letterSpacing: -0.4,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 카테고리 이미지 위젯 빌드
  Widget _buildCategoryImage({
    required double width,
    required double height,
    required double borderRadius,
    required String? photoUrl,
    required double devicePixelRatio,
  }) {
    return Container(
      width: width,
      height: height,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _kCategoryCardBorderColor, width: 1),
      ),
      child: _buildCategoryImageSurface(
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(borderRadius),
        photoUrl: photoUrl,
        devicePixelRatio: devicePixelRatio,
      ),
    );
  }

  Widget _buildCategoryImageSurface({
    required double width,
    required double height,
    required BorderRadius borderRadius,
    required String? photoUrl,
    required double devicePixelRatio,
  }) {
    final emptyBackgroundColor = isListView
        ? _kListEmptyCategoryBackgroundColor
        : _kEmptyCategoryBackgroundColor;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    if (hasPhoto) {
      final targetCacheWidth = (width * devicePixelRatio * 1.5).round();
      return ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          key: ValueKey('category_image_${category.id}'),
          imageUrl: photoUrl,
          cacheKey: _buildCategoryImageCacheKey(category.id, photoUrl),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          width: width,
          height: height,
          color: Colors.white.withValues(alpha: 0.8),
          colorBlendMode: BlendMode.modulate,
          memCacheWidth: targetCacheWidth,
          maxWidthDiskCache: targetCacheWidth,
          fit: BoxFit.cover,
          placeholder: (context, url) => ShimmerOnceThenFallbackIcon(
            key: ValueKey('ph_${category.id}'),
            width: width,
            height: height,
            borderRadius: borderRadius.topLeft.x,
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: emptyBackgroundColor,
              borderRadius: borderRadius,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        color: emptyBackgroundColor,
      ),
    );
  }

  /// 고정 배지 위젯 빌드
  /*Widget _buildPinnedBadge({double? top, double? left, double? right}) {
    return Selector<CategoryController, bool>(
      selector: (_, controller) =>
          controller.getCategoryById(category.id)?.isPinned ??
          category.isPinned,
      builder: (context, isPinned, _) {
        if (!isPinned) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: top,
          left: left,
          right: right,
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Image.asset('assets/pin_icon.png', width: 9, height: 9),
          ),
        );
      },
    );
  }*/

  /// 신규 배지 위젯 빌드
  Widget _buildNewBadge({
    double? top,
    double? left,
    double? right,
    required bool isNew,
  }) {
    if (!isNew) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: _buildNewBadgeContent(size: 15.sp, isNew: isNew),
    );
  }

  Widget _buildNewBadgeContent({required double size, required bool isNew}) {
    if (!isNew) {
      return const SizedBox.shrink();
    }

    return Image.asset('assets/new_icon.png', width: size, height: size);
  }

  // 프로필 Row 위젯 빌드 (리스트 스타일과 그리드 스타일 모두에서 사용)
  Widget _buildProfileRow({
    required CategoryProfileRowData profileRowData,
    required bool isListStyle,
  }) {
    final profileRow = ApiArchiveProfileRowWidget(
      profileUrlKeys: profileRowData.profileUrlKeys,
      totalUserCount: profileRowData.totalUserCount,
      avatarSize: isListStyle ? 19.84.sp : 23.44.sp,
    );

    if (!isListStyle) {
      return profileRow;
    }

    return profileRow;
  }

  /// 카테고리 데이터 프리페칭
  ///
  /// 화면 전환 전에 미리 데이터를 로드하여 즉시 표시 가능하도록 합니다.
  /// 네비게이션 애니메이션(~300ms) 동안 API 호출이 완료될 수 있습니다.
  void _prefetchCategoryHeaderImage(
    BuildContext context,
    CategoryHeaderImagePrefetch payload,
  ) {
    unawaited(
      CategoryHeaderImagePrefetchRegistry.prefetchIfNeeded(context, payload),
    );
  }

  Future<void> _prefetchCategoryData({
    required PostController postController,
    required FriendController friendController,
    required int categoryId,
    required int userId,
  }) async {
    try {
      // 병렬로 프리페칭
      await Future.wait([
        postController.getPostsByCategory(
          categoryId: categoryId,
          userId: userId,
          notificationId: null,
        ),
        friendController.getAllFriends(
          userId: userId,
          status: FriendStatus.blocked,
        ),
      ]);

      if (kDebugMode) {
        debugPrint('[Prefetch] 카테고리 $categoryId 데이터 프리페칭 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Prefetch] 프리페칭 실패 (무시됨): $e');
      }
      // 프리페칭 실패는 무시 (화면에서 다시 시도함)
    }
  }
}
