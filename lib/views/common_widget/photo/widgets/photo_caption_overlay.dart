import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../comment/comment_circle_avatar.dart';
import '../first_line_ellipsis_text.dart';

class ApiPhotoCaptionOverlay extends StatelessWidget {
  ///
  /// 이미지/비디오 위에 포스트 작성자 정보와 캡션을 오버레이로 보여주는 위젯입니다.
  /// - 포스트 작성자의 프로필 사진과 캡션 텍스트를 함께 보여주는 오버레이입니다.
  /// - 캡션이 길 경우, 기본적으로는 한 줄로 보여주고, 탭하면 전체 내용을 스크롤 가능한 형태로 확장하여 보여줍니다.
  /// - 작성자 프로필 사진이 로딩 중인 경우, 셰이머 효과로 로딩 상태를 표시합니다.
  /// - 작성자 프로필 사진이 로딩 완료된 경우, 원형 아바타로 보여줍니다.
  ///
  /// fields:
  /// - [content]: 포스트의 캡션 텍스트입니다.
  /// - [isExpanded]: 캡션이 확장되어 전체 내용이 보이는지 여부를 나타내는 플래그입니다.
  /// - [isProfileLoading]: 작성자 프로필 사진이 로딩 중인지 여부를 나타내는 플래그입니다.
  /// - [profileImageUrl]: 작성자 프로필 사진의 URL입니다. null이거나 빈 문자열인 경우 기본 아바타 이미지가 보여집니다.
  /// - [profileImageCacheKey]: 작성자 프로필 사진의 캐시 키입니다. null이거나 빈 문자열인 경우 imageUrl을 기반으로 캐시 키가 생성됩니다.
  /// - [onTap]: 캡션 오버레이가 탭되었을 때 호출되는 콜백입니다. 캡션 확장/축소 토글 등의 동작을 수행하는 데 사용됩니다.
  ///
  const ApiPhotoCaptionOverlay({
    super.key,
    required this.content,
    required this.isExpanded,
    required this.isProfileLoading,
    required this.profileImageUrl,
    required this.profileImageCacheKey,
    required this.onTap,
  });

  final String content;
  final bool isExpanded;
  final bool isProfileLoading;
  final String? profileImageUrl;
  final String? profileImageCacheKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.sp,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
    );

    const avatarSize = 27.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(13.6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
        child: Row(
          crossAxisAlignment: isExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: isProfileLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[600]!,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2A2A),
                        ),
                      ),
                    )
                  : CommentCircleAvatar(
                      imageUrl: profileImageUrl,
                      size: avatarSize,
                      cacheKey: profileImageCacheKey,
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: isExpanded
                  ? ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.05, 0.95, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.h),
                          child: Text(content, style: captionStyle),
                        ),
                      ),
                    )
                  : FirstLineEllipsisText(text: content, style: captionStyle),
            ),
          ],
        ),
      ),
    );
  }
}
