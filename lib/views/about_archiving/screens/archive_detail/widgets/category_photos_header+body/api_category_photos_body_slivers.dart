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

/// 카테고리 사진 화면에서 "실제 사진 그리드를 보여주는" 슬리버 위젯
///
/// Parameters:
///   - [posts]: 그리드에 표시할 포스트 목록
///   - [categoryName]: 현재 카테고리의 이름 (포스트 상세 화면에서 사용)
///   - [categoryId]: 현재 카테고리의 ID (포스트 상세 화면에서 사용)
///   - [padding]: 그리드 주변에 적용할 패딩
///   - [crossAxisCount]: 가로 열 개수
///   - [mainAxisSpacing]: 세로 간격
///   - [crossAxisSpacing]: 가로 간격
///   - [onPostsDeleted]: 포스트가 삭제되었을 때 호출되는 콜백 함수, 삭제된 포스트의 ID 목록을 인자로 받음
///
/// Returns:
///   - SliverPadding과 SliverMasonryGrid를 사용하여, 빈 공간 없이 포스트를 표시.
///     각 그리드 아이템은 ApiPhotoGridItem 위젯
class ApiCategoryPhotosGridSliver extends StatelessWidget {
  final List<Post> posts;
  final String categoryName;
  final int categoryId;
  final EdgeInsets padding;
  final int crossAxisCount; // 그리드의 열 개수
  final double mainAxisSpacing; // 그리드의 행 간격
  final double crossAxisSpacing; // 그리드의 열 간격
  final ValueChanged<List<int>> onPostsDeleted;

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
  Widget build(BuildContext context) {
    // 최소 2열을 유지하도록 설정, 필요에 따라 조정 가능
    const minimumCrossAxisCount = 2;

    // crossAxisCount가 minimumCrossAxisCount보다 작은 경우,
    // minimumCrossAxisCount로 설정하여 그리드가 너무 적은 열로 표시되는 것을 방지
    final effectiveCrossAxisCount = crossAxisCount < minimumCrossAxisCount
        ? minimumCrossAxisCount
        : crossAxisCount;

    // 포스트를 최신순으로 정렬하는 로직 추가
    // (createdAt이 null인 경우 ID로 대체하여 내림차순 정렬)
    final sortedPosts = List<Post>.from(posts)
      ..sort((a, b) {
        final aTime = a.createdAt; // a의 생성 시간
        final bTime = b.createdAt; // b의 생성 시간

        // 둘 다 createdAt이 존재하는 경우, createdAt으로 비교
        if (aTime != null && bTime != null) {
          final cmp = bTime.compareTo(aTime); // 최신순으로 정렬
          if (cmp != 0) return cmp; // createdAt이 다른 경우, 그 결과를 반환
        }
        // aTime(createdAt)이 존재하는 경우, a가 더 최신으로 간주
        else if (aTime != null) {
          return -1;
        }
        // bTime(createdAt)이 존재하는 경우, b가 더 최신으로 간주
        else if (bTime != null) {
          return 1;
        }

        // ID로 내림차순 (최신순)
        return b.id.compareTo(a.id);
      });

    return SliverPadding(
      padding: padding,
      sliver: SliverMasonryGrid.count(
        crossAxisCount: effectiveCrossAxisCount, // 최소 열 개수 적용 -> Row 수 조정
        mainAxisSpacing: mainAxisSpacing, // 행 간격 적용 -> Column 간격 조정
        crossAxisSpacing: crossAxisSpacing, // 열 간격 적용 -> Row 간격 조정
        childCount: sortedPosts.length, // 그리드에 표시할 아이템 수 -> 포스트 수에 따라 동적으로 결정
        itemBuilder: (context, index) {
          final post = sortedPosts[index]; // 정렬된 포스트 목록에서 현재 인덱스에 해당하는 포스트 가져오기
          return ApiPhotoGridItem(
            key: ValueKey(
              'grid_${categoryId}_${post.id}',
            ), // 고유한 키 생성 (카테고리 ID와 포스트 ID를 조합하여 생성)
            post: post,
            postUrl: post.postFileUrl ?? '',
            allPosts: sortedPosts,
            currentIndex: index,
            categoryName: categoryName,
            categoryId: categoryId,
            initialCommentCount: post.commentCount ?? 0,
            onPostsDeleted: onPostsDeleted,
          );
        },
      ),
    );
  }
}
