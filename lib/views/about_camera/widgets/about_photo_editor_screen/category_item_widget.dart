import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// URL에서 캐시 키를 유도합니다. host + path를 조합하여 쿼리스트링 변경 시에도 동일 키를 반환합니다.
String? deriveCategoryImageCacheKey(String imageUrl) {
  final uri = Uri.tryParse(imageUrl);
  if (uri == null) return null;

  final normalizedPath = uri.path.trim();
  if (normalizedPath.isEmpty) return null;

  final normalizedHost = uri.host.trim();
  if (normalizedHost.isEmpty) return normalizedPath;

  return '$normalizedHost$normalizedPath';
}

/// 카테고리 아이템 위젯
/// 각 카테고리를 표현하는 UI 요소입니다.
/// 아이콘이나 이미지 URL을 함께 표시할 수 있습니다.
class CategoryItemWidget extends StatefulWidget {
  final String? imageUrl;
  final String? image;
  final String label;
  final VoidCallback onTap;
  final int? categoryId;
  final List<int>? selectedCategoryIds;

  const CategoryItemWidget({
    super.key,
    this.imageUrl,
    this.image,
    required this.label,
    required this.onTap,
    this.categoryId,
    this.selectedCategoryIds,
  });

  @override
  State<CategoryItemWidget> createState() => _CategoryItemWidgetState();
}

class _CategoryItemWidgetState extends State<CategoryItemWidget> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSelected = _isSelectedCategory();
    final dimensions = _calculateDimensions(screenWidth);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200), // 선택 시 부드러운 애니메이션
        width: dimensions.itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircularContainer(dimensions, isSelected), //
            SizedBox(height: 12.h),
            _buildCategoryLabel(dimensions), // 카테고리 라벨
          ],
        ),
      ),
    );
  }

  /// 선택된 카테고리인지 확인
  bool _isSelectedCategory() {
    return widget.categoryId != null &&
        widget.selectedCategoryIds?.contains(widget.categoryId) == true;
  }

  /// 화면 크기에 따른 반응형 치수 계산
  _CategoryDimensions _calculateDimensions(double screenWidth) {
    // GridView가 4열이고 패딩과 간격을 고려한 실제 아이템 너비 계산
    final totalPadding = (screenWidth * 0.08).clamp(24.0, 36.0); // 좌우 패딩 총합
    final totalSpacing = 8.0 * 3; // crossAxisSpacing * (열 수 - 1)
    final availableWidth = screenWidth - totalPadding - totalSpacing;
    final itemWidth = availableWidth / 4;

    return _CategoryDimensions(
      itemWidth: itemWidth,
      containerSize: (itemWidth * 0.75).clamp(50.0, 65.0), // 아이템 너비의 75%
      margin: 0, // margin 제거

      borderWidth: (screenWidth * 0.005).clamp(2.0, 3.0),
      iconSize: (itemWidth * 0.4).clamp(25.0, 32.0), // 컨테이너 크기에 비례
      smallIconSize: (itemWidth * 0.3).clamp(20.0, 26.0),
      strokeWidth: (screenWidth * 0.005).clamp(1.5, 2.5),
      fontSize: (screenWidth * 0.032).clamp(11.0, 14.0), // 텍스트 크기 약간 증가
    );
  }

  /// 원형 컨테이너 빌드
  Widget _buildCircularContainer(
    _CategoryDimensions dimensions,
    bool isSelected,
  ) {
    return Container(
      width: dimensions.containerSize,
      height: dimensions.containerSize,
      decoration: BoxDecoration(
        color: (widget.image != null) ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // 배경 이미지/아이콘
            Center(child: _buildContainerChild(dimensions)),

            // 선택된 상태일 때 오버레이와 전송 아이콘
            if (isSelected) _buildSelectionOverlay(dimensions),
          ],
        ),
      ),
    );
  }

  /// 컨테이너 내부 위젯 빌드
  Widget _buildContainerChild(_CategoryDimensions dimensions) {
    // 기본 아이콘이 있는 경우 (추가하기 버튼)
    if (widget.image != null) {
      return Image.asset(
        widget.image!,
        color: Colors.black,
        width: 27.w,
        height: 27.h,
        fit: BoxFit.cover,
      );
    }

    // 이미지 URL이 있는 경우
    final imageUrl = widget.imageUrl?.trim() ?? '';
    if (imageUrl.isNotEmpty) {
      // 캐시 키 유도
      // 캐시 키를 유도하여 URL이 변경되어도 동일한 이미지를 사용할 수 있도록 합니다.
      final imageCacheKey = deriveCategoryImageCacheKey(imageUrl);
      return SizedBox(
        width: dimensions.containerSize, // 컨테이너 크기와 일치
        height: dimensions.containerSize, // 컨테이너 크기와 일치
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: imageCacheKey,
          useOldImageOnUrlChange: imageCacheKey != null,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          fit: BoxFit.cover,
          width: dimensions.containerSize,
          height: dimensions.containerSize,
          memCacheWidth: (dimensions.containerSize * 3).round(),
          maxWidthDiskCache: (dimensions.containerSize * 3).round(),
          placeholder: (context, url) => _buildShimmer(dimensions),
          errorWidget: (context, url, error) => _buildErrorIcon(dimensions),
        ),
      );
    }

    // 기본 이미지 아이콘
    return Container(
      decoration: BoxDecoration(color: Color(0xff4a4a4a)),
      width: dimensions.containerSize, // 컨테이너 크기와 일치
      height: dimensions.containerSize, // 컨테이너 크기와 일치
      child: Icon(
        Icons.image_outlined,
        size: dimensions.iconSize,
        color: Color(0xffcecece),
      ),
    );
  }

  /// 카테고리가 선택된 상태의 오버레이 위젯
  Widget _buildSelectionOverlay(_CategoryDimensions dimensions) {
    return Container(
      width: dimensions.containerSize,
      height: dimensions.containerSize,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.only(left: 2.w, bottom: 2.h),
        child: Center(
          child: Image.asset(
            'assets/send_imoji.png',
            width: 42.76,
            height: 42.76,
          ),
        ),
      ),
    );
  }

  /// 로딩 인디케이터 빌드
  Widget _buildShimmer(_CategoryDimensions dimensions) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade600,
      highlightColor: Colors.grey.shade400,
      child: Container(
        width: dimensions.containerSize,
        height: dimensions.containerSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 에러 아이콘 빌드
  Widget _buildErrorIcon(_CategoryDimensions dimensions) {
    return Container(
      decoration: BoxDecoration(color: Color(0xff4a4a4a)),
      width: dimensions.containerSize, // 컨테이너 크기와 일치
      height: dimensions.containerSize, // 컨테이너 크기와 일치
      child: Icon(
        Icons.image_outlined,
        size: dimensions.iconSize,
        color: Color(0xffcecece),
      ),
    );
  }

  /// 카테고리 라벨 빌드
  Widget _buildCategoryLabel(_CategoryDimensions dimensions) {
    return Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard',
        color: Colors.white,
        height: 1.0,
        letterSpacing: -0.4,
      ),
    );
  }
}

/// 카테고리 아이템의 반응형 치수를 관리하는 클래스
class _CategoryDimensions {
  final double itemWidth;
  final double containerSize;
  final double margin;

  final double borderWidth;
  final double iconSize;
  final double smallIconSize;
  final double strokeWidth;
  final double fontSize;

  const _CategoryDimensions({
    required this.itemWidth,
    required this.containerSize,
    required this.margin,

    required this.borderWidth,
    required this.iconSize,
    required this.smallIconSize,
    required this.strokeWidth,
    required this.fontSize,
  });
}
