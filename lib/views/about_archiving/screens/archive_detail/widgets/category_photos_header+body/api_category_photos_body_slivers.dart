import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../../../api/models/post.dart';
import '../../../../widgets/api_photo_grid_item.dart';
import '../../../../widgets/archive_card_widget/archive_card_placeholders.dart';

/// 카테고리 사진 화면에서 "로딩 중" 상태일 때 보여주는 슬리버 위젯
///
/// Parameters:
///   - [padding]: 그리드 주변에 적용할 패딩
///   - [crossAxisCount]: 가로 열 개수
///   - [mainAxisSpacing]: 세로 간격
///   - [crossAxisSpacing]: 가로 간격
/// Returns:
///   - SliverPadding과 SliverGrid를 사용하여, 빈 공간 없이 로딩 상태를 표시.
///   - 각 그리드 아이템은 ShimmerOnceThenFallbackIcon 위젯
class ApiCategoryPhotosLoadingSliver extends StatelessWidget {
  final EdgeInsets padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const ApiCategoryPhotosLoadingSliver({
    super.key,
    required this.padding,
    required this.crossAxisCount,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 170 / 204,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return ShimmerOnceThenFallbackIcon(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                borderRadius: 8,
                shimmerCycles: 2,
              );
            },
          );
        }, childCount: 6),
      ),
    );
  }
}

/// 카테고리 사진 화면에서 "에러"가 발생했을 때 보여주는 슬리버 위젯
///
/// Parameters:
///   - [errorMessageKey]: 에러 메시지의 로컬라이즈된 키
///   - [onRetry]: 재시도 버튼이 눌렸을 때 호출되는 콜백 함수
///
/// Returns:
///   - SliverFillRemaining을 사용하여 화면 중앙에 에러 메시지와 재시도 버튼을 표시
class ApiCategoryPhotosErrorSliver extends StatelessWidget {
  final String errorMessageKey;
  final Future<void> Function() onRetry;

  const ApiCategoryPhotosErrorSliver({
    super.key,
    required this.errorMessageKey,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessageKey,
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
                textAlign: TextAlign.center,
              ).tr(),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  onRetry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
                child: Text(
                  'common.retry',
                  style: TextStyle(color: Colors.white),
                ).tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 사진 화면에서 사진이 "하나도 없을 때" 보여주는 슬리버 위젯
///
/// Parameters:
///   - 없음
///
/// Returns:
///   - SliverFillRemaining을 사용하여 화면 중앙에 빈 상태 메시지를 표시
class ApiCategoryPhotosEmptySliver extends StatelessWidget {
  const ApiCategoryPhotosEmptySliver({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Text(
            'archive.empty_photos',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
            textAlign: TextAlign.center,
          ).tr(),
        ),
      ),
    );
  }
}

class ApiCategoryPhotosGridSliver extends StatefulWidget {
  final List<Post> posts;
  final String categoryName;
  final int categoryId;
  final EdgeInsets padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final ValueChanged<List<int>> onPostsDeleted;

  /// 카테고리 사진 화면에서 "실제 사진 그리드를 보여주는" 슬리버 위젯
  ///
  /// fields:
  /// - [posts]: 그리드에 표시할 포스트 목록
  /// - [categoryName]: 현재 카테고리의 이름 (포스트 상세 화면에서 사용)
  /// - [categoryId]: 현재 카테고리의 ID (포스트 상세 화면에서 사용)
  /// - [padding]: 그리드 주변에 적용할 패딩
  /// - [crossAxisCount]: 가로 열 개수
  /// - [mainAxisSpacing]: 세로 간격
  /// - [crossAxisSpacing]: 가로 간격
  /// - [onPostsDeleted]: 포스트가 삭제되었을 때 호출되는 콜백 함수, 삭제된 포스트의 ID 목록을 인자로 받음
  ///
  /// Returns:
  /// - SliverPadding과 SliverMasonryGrid를 사용하여, 포스트 목록을 시간순으로 정렬하여 그리드 형태로 표시.
  /// - 각 그리드 아이템은 ApiPhotoGridItem 위젯으로 구성되며, 포스트 상세 화면으로 이동할 때 카테고리 이름과 ID를 전달.

  const ApiCategoryPhotosGridSliver({
    super.key,
    required this.posts,
    required this.categoryName,
    required this.categoryId,
    required this.padding,
    required this.crossAxisCount,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.onPostsDeleted,
  });

  @override
  State<ApiCategoryPhotosGridSliver> createState() =>
      _ApiCategoryPhotosGridSliverState();
}

class _ApiCategoryPhotosGridSliverState
    extends State<ApiCategoryPhotosGridSliver> {
  // posts 참조가 바뀔 때만 재정렬 (O(n log n) → O(1) on cache hit)

  /// 정렬된 포스트 목록을 캐싱하여, 동일한 리스트에 대해서는 재정렬을 방지합니다.
  List<Post>? _sortedPosts;

  /// 마지막으로 정렬에 사용된 원본 포스트 리스트를 참조하여, 동일한 리스트에 대해서는 재정렬을 방지합니다.
  List<Post>? _lastSourcePosts;

  /// 정렬 comparator를 static으로 추출하여 매 build마다 클로저 할당 방지
  /// - 최신순 정렬: createdAt이 최신인 순서대로 (null은 가장 오래된 것으로 간주)
  static int _compareByTime(Post a, Post b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime != null && bTime != null) {
      final cmp = bTime.compareTo(aTime);
      if (cmp != 0) return cmp;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }
    return b.id.compareTo(a.id);
  }

  /// 원본 포스트 리스트가 변경되었을 때만 정렬을 수행하여, 동일한 리스트에 대해서는 캐시된 정렬 결과를 반환합니다.
  /// - 동일한 리스트에 대해서는 O(1)로 정렬된 결과를 반환하여 성능 최적화
  List<Post> _getOrComputeSortedPosts() {
    // identical()로 참조 동일성 비교 → 같은 리스트면 재정렬 생략
    if (!identical(_lastSourcePosts, widget.posts)) {
      _lastSourcePosts = widget.posts;
      _sortedPosts = List<Post>.from(widget.posts)..sort(_compareByTime);
    }
    return _sortedPosts!;
  }

  @override
  Widget build(BuildContext context) {
    const minimumCrossAxisCount = 2;
    final effectiveCrossAxisCount =
        widget.crossAxisCount < minimumCrossAxisCount
        ? minimumCrossAxisCount
        : widget.crossAxisCount;

    final sortedPosts = _getOrComputeSortedPosts();

    return SliverPadding(
      padding: widget.padding,
      sliver: SliverMasonryGrid.count(
        crossAxisCount: effectiveCrossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childCount: sortedPosts.length,
        itemBuilder: (context, index) {
          final post = sortedPosts[index];
          return ApiPhotoGridItem(
            key: ValueKey('grid_${widget.categoryId}_${post.id}'),
            post: post,
            postUrl: post.postFileUrl ?? '',
            allPosts: sortedPosts,
            currentIndex: index,
            categoryName: widget.categoryName,
            categoryId: widget.categoryId,
            initialCommentCount: post.commentCount ?? 0,
            onPostsDeleted: widget.onPostsDeleted,
          );
        },
      ),
    );
  }
}
